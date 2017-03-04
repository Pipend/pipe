{bind-p, return-p, to-callback} = require \./async-ls
require! \base62
require! \express
require! \express-session
RedisSessionStore = (require \connect-redis) express-session
require! \passport
GitHubStrategy = require \passport-github2 .Strategy
{camelize, each, id, last, map, Obj, obj-to-pairs, pairs-to-obj, partition} = require \prelude-ls
require! \./exceptions/DocumentSaveException
require! \./exceptions/UnAuthenticatedException
require! \./exceptions/UnAuthorizedException
{compile-transformation} = require \pipe-transformation
require! \querystring

# Res -> Error -> Void
die = (res, err) !->
    console.log "DEAD BECAUSE OF ERROR:", err
    res.status 500 .send err

# partition-data-source-cue-params :: ParsedQueryString -> Tuple DataSourceCueParams ParsedQueryString
partition-data-source-cue-params = (query) ->
    query
    |> obj-to-pairs
    |> partition (0 ==) . (.0.index-of 'dsc-')
    |> ([ds, qs]) ->
        [(ds |> map ([k,v]) -> [(camelize k.replace /^dsc-/, ''),v]), qs]
            |> map pairs-to-obj

# query-parser :: String -> a
# query-parser :: [String] -> [a]
# query-parser :: Map String, String -> Map String, a
query-parser = (value) ->
    match typeof! value
    | \Array => value |> map -> query-parser it
    | \Object =>
        value
            |> obj-to-pairs
            |> map ([key, value]) -> [key, query-parser value]
            |> pairs-to-obj
    | \String =>
        value-parser =
            | (/^(\-|\+)*\d+$/g.test value) => parse-int
            | (/^(\-|\+)*(\d|\.)+$/g.test value) => parse-float
            | value == \true => -> true
            | value == \false => -> false
            | value == '' => -> undefined
            | _ => id
        value-parser value

# send :: ExpressResponse -> p object -> ()
send = (response, promise) !->
    err, result <- to-callback promise
    if err then die response, err else response.send result

module.exports = (
    strategies
    {
        public-actions,
        authentication-dependant-actions,
        authorization-dependant-actions,
    }
    spy
    http-port
) ->

    handle = (is-api, p, response) -->

        # error and redirect utility functions
        error = (status, msg) ->
            console.error 'routes.ls handle error', status, is-api, msg
            response.status status
            if is-api
                then response.send {error: msg}
                else
                    response.set \Content-disposition, ""
                    response.set \Content-type, "text"
                    response.end msg

        redirect = (status, msg, url) ->
            response.status status
            if is-api then response.send {error: msg} else response.redirect url

        ex, result <- to-callback p

        if ex
            if ex instanceof UnAuthorizedException
                error 403, "You must be a Collaborator"

            else if ex instanceof UnAuthenticatedException
                redirect 401, 'You must log in', '/login'

            else if ex instanceof DocumentSaveException
                error 500, ex.versions-ahead

            else
                error 500, "#{ex}"

        else

            # result is either a value or a function that takes response
            # result :: value
            # result :: response -> ()

            if \Function == typeof! result
                try
                    result response
                catch ex
                    error 500, ex.to-string!
            else
                response.send result

    ensure-authorized = (f, req, res) -->
        handle do
            'application/json' == req.headers['content-type']
            (authorization-dependant-actions req.user?._id, req.params.project-id).then (actions) ->
                f actions, req, res
            res

    ensure-authenticated = (f, req, res) -->
        handle do
            'application/json' == req.headers['content-type']
            (authentication-dependant-actions req.user?._id).then (actions) -->
                f actions, req, res
            res

    no-security = (f, req, res) -->
        handle do
            'application/json' == req.headers['content-type']
            public-actions!.then (actions) ->
                f actions, req, res
            res


    ## ---------- middleware -----------

    parse-query-string =
        methods: <[use]>
        request-handler: (req, res, next) ->
            if req.query
                req.parsed-query = query-parser req.query
            next!

    restrict-post-body-size =
        methods: <[use]>
        request-handler: (req, res, next) ->
            if req.method in <[POST PUT]>
                body = ""
                size = 0
                req.on \data, ->
                    size += it.length
                    if size > 4e6
                        res.write-head 413, \Connection : \close
                        res.end "File size exceeded"
                    body += it
                req.on \end, ->
                    req <<< body: JSON.parse body
                    next!

            else
                next!


    # ----------- auth -----------

    passport
        ..use new GitHubStrategy strategies.github, (, , profile, callback) ->
            to-callback do
                do ->
                    {get-user-by-oauth-id, insert-user} <- bind-p public-actions!
                    user <- bind-p (get-user-by-oauth-id \github, profile._json.id)
                    if user
                        return-p user
                    else
                        insert-user github-profile: profile._json
                callback

        ..serialize-user ({_id}?, callback) ->
            callback null, _id

        ..deserialize-user (_id, callback) ->
            callback null, {_id}

    init-express-session =
        methods: <[use]>
        request-handler: express-session do
            resave: false
            save-uninitialized: false
            secret: 'test'
            store: new RedisSessionStore do
                host: \127.0.0.1
                port: 6379

    init-passport =
        methods: <[use]>
        request-handler: passport.initialize!

    init-passport-session =
        methods: <[use]>
        request-handler: passport.session!

    fake-user =
        methods: <[use]>
        request-handler: (req, res, next) ->
            if req.query.user-id and !req.session.passport
                req.session <<<
                    passport:
                        user:
                            _id: req.query.user-id

            if req.session.passport
                req.user = req.session.passport.user

            next!

    login-page =
        methods: <[get post]>
        patterns: <[/login]>
        request-handler: (req, res) ->
            res.send "login"

    github-oauth-redirect =
        methods: <[get]>
        patterns: <[/auth/github]>
        middlewares:
            *   passport.authenticate do
                    \github
                    scope: <[user:email]>
            ...

    github-oauth-callback =
        methods: <[get]>
        patterns: <[/auth/github/callback]>
        middlewares:
            *   passport.authenticate do
                    \github
                    failure-redirect: \/login
                    success-redirect: \/


    # ----------- projects -----------

    # create a new project for the user-id (owner)
    # requires user to be only authenticated
    insert-project =
        methods: <[post]>
        patterns: <[/apis/projects]>
        request-handler: ensure-authenticated (actions, req) ->
            actions.insert-project req.body

    # get my projects
    get-projects =
        methods: <[get]>
        patterns: <[/apis/projects]>
        request-handler: ensure-authenticated (actions, req) ->
            actions.get-projects req.user?._id

    get-projects-by-user-id =
        methods: <[get]>
        patterns: <[/apis/users/:userId/projects]>
        request-handler: ensure-authenticated (actions, req) ->
            actions.get-projects req.params.user-id

    get-project =
        methods: <[get]>
        patterns: <[/apis/projects/:projectId]>
        request-handler: ensure-authorized (actions, req) ->
            actions.get-project req.params.project-id

    update-project =
        methods: <[put]>
        patterns: <[/apis/projects/:projectId]>
        request-handler: ensure-authorized (actions, req) ->
            actions.update-project req.body

    # can be invoked by owner only
    delete-project =
        methods: <[delete]>
        patterns: <[/apis/projects/:projectId]>
        request-handler: ensure-authorized (actions, req) ->
            console.log \DELETE
            actions.delete-project!


    # ----------- documents -----------

    save-document =
        methods: <[post]>
        patterns: <[/apis/projects/:projectId/documents]>
        request-handler: ensure-authorized (actions, req) ->
            actions.save-document req.body

    # information about a single document
    get-document-version =
        methods: <[get]>
        patterns: <[/apis/projects/:projectId/documents/:documentId/versions/:version]>
        request-handler:
            ensure-authorized (actions, req) ->
                actions.get-document-version req.params.document-id, (parse-int req.params.version)

    get-document-history =
        methods: <[get]>
        patterns: <[/apis/projects/:projectId/documents/:documentId/versions]>
        request-handler: ensure-authorized (actions, req) ->
            actions.get-document-history req.params.document-id

    # returns a list of queries where each item has the query-id and its latest-version
    get-documents-in-a-project =
        methods: <[get]>
        patterns: <[/apis/projects/:projectId/documents]>
        request-handler: ensure-authorized (actions) ->
            actions.get-documents-in-a-project!

    # can be invoked by owner, admin or collaborator
    # sets the status property of all the versions of the document to false
    delete-document-and-hisotry =
        methods: <[delete]>
        patterns: <[/apis/projects/:projectId/documents/:documentId]>
        request-handler: ensure-authorized (actions, req) ->
            actions.delete-document-and-history req.params.document-id

    # can be invoked by owner, admin or collaborator
    # sets the status property of the given version of the document to false
    delete-document-version =
        methods: <[delete]>
        patterns: <[/apis/projects/:projectId/documents/:documentId/versions/:version]>
        request-handler: ensure-authorized (actions, req) ->
            actions.delete-document-version req.params.document-id, (parse-int req.params.version)


    # ----------- editor -----------

    # returns a list of all the databases/collections or databases/tables (Depending on queryType)
    # used in the dropdown
    connections =
        methods: <[get]>
        patterns: <[/apis/projects/:projectId/queryTypes/:queryType/connections]>
        request-handler: ensure-authorized (actions, req) ->
            actions.get-connections req.params.query-type, req.query

    #TODO: must be re-implemented
    # returns the default document for the given query-type & transpilation-language
    default-document =
        methods: <[post]>
        patterns: <[/apis/projects/:projectId/defaultDocument]>
        request-handler: (req, res) ->
            {data-source-cue, transpilation-language} = req.body
            {default-document} = require "./query-types/#{data-source-cue.query-type}"
            res.send {} <<< (default-document data-source-cue, transpilation-language) <<<
                data-source-cue: data-source-cue
                query-title: 'Untitled query'
                tags: []
                transpilation:
                    query: transpilation-language
                    transformation: transpilation-language
                    presentation: transpilation-language

    #TODO: must be re-implemented with authorization
    keywords =
        methods: <[post]>
        patterns: <[/apis/projects/:projectId/keywords]>
        request-handler: ensure-authorized (actions, req, res) ->
            [data-source-cue, ...rest] = req.body
            {query-type}:data-source <- bind-p actions.extract-data-source data-source-cue
            results <- bind-p (require "./query-types/#{query-type}").keywords [data-source] ++ rest
            return-p results




    # ----------- execution -----------

    execute-post =
        methods: <[post]>
        patterns: <[/apis/projects/:projectId/documents/:documentId/versions/:version/execute]>
        request-handler: ensure-authorized (actions, req, res) ->
            document-id = req.params.document-id
            version = (parse-int req.params.version)

            # pattern match the required fields
            {
                task-id
                display
                data-source-cue
                query
                transpilation-language
                compiled-parameters
                cache
            }? = req.body

            # set the req / res timeout from data-source
            {timeout}:data-source <- bind-p actions.extract-data-source data-source-cue
            [req, res] |> each (.connection.set-timeout timeout ? 90000)

            actions.execute do
                task-id
                {} <<< display <<<
                    url: req.url
                    method: req.method
                    user-agent: req.headers[\user-agent]
                document-id
                version
                data-source-cue
                query
                transpilation-language
                compiled-parameters
                cache


    execute-document =
        methods: <[get]>
        patterns: <[
            /apis/projects/:projectId/documents/:documentId/execute
            /apis/projects/:projectId/documents/:documentId/versions/:version/execute
        ]>
        optional-params: <[cache display]>
        request-handler: ensure-authorized (actions, req, res) ->
            {document-id, version, cache, display or \query}? = req.params
            cache = if !!cache then query-parser cache else false
            task-id = base62.encode Date.now!

            # get the query from query-id (if present) otherwise get the latest query in the branch-id
            document <- bind-p do ->
                if !!document-id and !!version
                    actions.get-document-version document-id, (parse-int version)

                else
                    actions.get-latest-document document-id

            {
                version
                data-source-cue
                transpilation
                query
                transformation
                presentation
                client-external-libs
            } = document

            # user can override PartialDataSource properties by providing ds- parameters in the query string
            [data-source-cue-params, compiled-parameters] = partition-data-source-cue-params req.parsed-query

            # req/res timeout
            {timeout}:data-source <- bind-p actions.extract-data-source {} <<< data-source-cue <<< data-source-cue-params
            [req, res] |> each (.connection.set-timeout timeout ? 90000)

            # execute the query
            task-info = document
            {result} <- bind-p do
                actions.execute do
                    task-id
                    url: req.url
                    method: req.method
                    user-agent: req.headers[\user-agent]
                    document-title: document.title
                    document-id
                    version
                    data-source-cue
                    query
                    transpilation.query
                    compiled-parameters
                    cache

            # returns :: p (res) -> IO ()
            switch display
            | \query =>
                return-p (res) !-> res.send result

            | \transformation =>
                transformation-function <- bind-p (compile-transformation transformation, transpilation.transformation)
                return-p (res) !-> res.send (transformation-function result, compiled-parameters)

            | _ =>
                return-p (res) !->
                    res.render \public/presentation.html, {
                        query-result: result
                        transpilation
                        transformation
                        presentation
                        compiled-parameters
                        client-external-libs
                    }


    # ----------- ops -----------

    ops =
        methods: <[get]>
        patterns: <[/apis/projects/:projectId/tasks]>
        request-handler: ensure-authorized (actions, req) ->
            actions.running-tasks!

    cancel-task =
        methods: <[get]>
        patterns: <[/apis/projects/:projectId/tasks/:taskId/cancel]>
        request-handler: ensure-authorized (actions, req) ->
            actions.cancel-task req.params.task-id


    # ----------- export -----------

    # export a screenshot of the result
    export-document =
        methods: <[get]>
        patterns: <[
            /apis/projects/:projectId/documents/:documentId/versions/:version/export
            /apis/projects/:projectId/documents/:documentId/export
        ]>
        optional-params: <[cache format width height timeout]>
        request-handler: ensure-authorized (actions, req, res) ->

            {document-id, version, cache, format or 'png', width or 720, height or 480, timeout}? = req.params
            cache := if !!cache then query-parser cache else false
            {snapshot} = req.query

            # validate format
            text-formats = <[json text]>
            valid-formats = <[png]> ++ text-formats
            return reject-p new Error "invalid format: #{format}, did you mean json?" if !(format in valid-formats)

            # find the query-id & title

            # use query-id if present, otherwise get the latest document for the given branch-id
            {data-source-cue}:document <- bind-p do ->
                if !!document-id and !!version
                    actions.get-document-version document-id, (parse-int version)

                else
                    actions.get-latest-document document-id

            # extract & separate data-source-cue from query-string
            [data-source-cue-params, compiled-parameters] = partition-data-source-cue-params req.parsed-query

            # extract data-source from data-source-cue (composed with data-source-cue-params extract from querystring above)
            data-source <- bind-p actions.extract-data-source {} <<< data-source-cue <<< data-source-cue-params

            {project-id, version, title, query, transformation, transpilation} = document

            # client side name for the snapshot image or text/json/csv file, part of the response header
            filename = title.replace /\s/g, '_'

            if format in text-formats
                task-id = base62.encode Date.now!
                [req, res] |> each (.connection.set-timeout data-source.timeout ? 90000)
                {result} <- bind-p do
                    actions.execute do
                        task-id
                        url: req.url
                        method: req.method
                        user-agent: req.headers[\user-agent]
                        document-title: document.title
                        document-id
                        version
                        data-source-cue
                        query
                        transpilation.query
                        compiled-parameters
                        cache

                transformation-function <- bind-p (compile-transformation transformation, transpilation.transformation)

                transformed-result = transformation-function result, transformation, compiled-parameters

                return-p (res) ->
                    download = (extension, content-type, content) ->
                        res.set \Content-disposition, "attachment; filename=#{filename}.#{extension}"
                        res.set \Content-type, content-type
                        res.end content
                    match format
                    | \json => download \json, \application/json, JSON.stringify(transformed-result)
                    | \text => download \txt, \text/plain, JSON.stringify(transformed-result)

            else # format is not in text-formats

                # server side name of the image file (composed of query-id or branch-id & current time)
                image-file = (
                    if snapshot
                        "public/snapshots/#{branch-id}.png"  # TODO?
                    else
                        "tmp/#{project-id}_#{document-id}_#{Date.now!}.png"
                )

                # screate and setup phantom instance
                phantom-instance <- bind-p phantom.create!
                phantom-page <- bind-p phantom-instance.create-page!

                <- bind-p phantom-page.property \customHeaders, {'X-Internal': '1', 'Cookie': req.headers.cookie}
                <- bind-p phantom-page.property \viewportSize, {width, height}
                <- bind-p phantom-page.property \clipRect, {width, height}

                # if this is a snapshot, then get the parameters from the document, otherwise use the querystring
                query-params <- bind-p do ->
                    if snapshot
                        compile-parameters document.parameters, transpilation.query, {}
                    else
                        return-p req.query

                # load the page in phantom
                <- bind-p phantom-page.open do
                    "http://127.0.0.1:#{http-port}/apis/projects/#{project-id}/documents/#{document-id}/versions/#{version}/execute/#{cache}/presentation?" +
                    querystring.stringify query-params

                # give the page time to settle in before taking a screenshot
                <- bind-p new Promise (resolve) ->
                    set-timeout resolve, timeout ? (config?.snapshot-timeout ? 1000)

                <- bind-p phantom-page.render image-file

                set-timeout do
                    -> phantom-instance.exit!
                    250

                return-p (res) ->
                    fs = require \fs

                    if snapshot
                        res.end "snapshot saved to #{image-file}"

                    # tell the browser to download the file
                    else
                        res.set \Content-disposition, "attachment; filename=#{filename}.png"
                        res.set \Content-type, \image/png
                        fs.create-read-stream image-file .pipe res


    # ----------- static -----------

    static-directories =
        *   methods: <[use]>
            patterns: <[/public]>
            request-handler: express.static "#__dirname/public/"

        *   methods: <[use]>
            patterns: <[/node_modules]>
            request-handler: express.static "#__dirname/node_modules/"
        ...

    # solves 404 errors
    non-existant-snapshots =
        methods: <[get]>
        patterns: <[/public/snapshots/*]>
        request-handler: (, res) ->
            res.status \content-type, \image/png
            res.end!

    # render index.html
    index-html =
        methods: <[get]>
        patterns: <[
            /
            /projects/new
            /projects/:projectId
            /projects/:projectId/edit
            /projects/:projectId/documents
            /projects/:projectId/documents/new
            /projects/:projectId/documents/:documentId/versions/:version
        ]>
        request-handler: (req, res) !->
            spy.record-req do
                req
                event-type: \visit

            res.render \public/index.html

    redirects =
        *   methods: <[get]>
            patterns: <[/projects/:projectId/documents/:documentId]>
            request-handler: ensure-authorized (actions, req, res) ->
                versions <- bind-p actions.get-document-history req.params.document-id
                {version} = last versions
                (res) ->
                    res.redirect "/projects/#{req.params.project-id}/documents/#{req.params.document-id}/versions/#{version}"
        ...

    [
        parse-query-string
        restrict-post-body-size
        init-express-session
        init-passport
        init-passport-session
        # fake-user
        github-oauth-redirect
        github-oauth-callback
        login-page
    ] ++
    static-directories ++
    [
        non-existant-snapshots
        index-html

        insert-project
        get-project
        get-projects
        get-projects-by-user-id
        update-project
        delete-project

        save-document
        get-document-version
        get-document-history
        get-documents-in-a-project
        delete-document-version
        delete-document-and-hisotry

        connections
        keywords
        default-document
        execute-post
        execute-document
        export-document
        ops
        cancel-task
    ] ++ redirects
