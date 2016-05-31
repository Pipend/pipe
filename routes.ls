{bind-p, from-error-value-callback, new-promise, return-p, to-callback} = require \./async-ls
require! \base62
Busboy = require \busboy
require! \express
{create-read-stream, readdir} = require \fs
require! \moment
require! \phantom
{compile-parameters, compile-transformation} = require \pipe-transformation

# prelude
{any, camelize, difference, each, filter, find, find-index, fold, group-by, id, map, maximum-by,
Obj, obj-to-pairs, pairs-to-obj, partition, reject, Str, sort, sort-by, unique, values} = require \prelude-ls

require! \querystring
url-parser = (require \url).parse
{extract-data-source}:utils = require \./utils

# ExpressRoute :: {
#     methods :: [String]
#     patterns :: [String]
#     optional-params :: [String]
#     request-handler :: ExpressRequest -> ExpressResponse -> ()
# }
# QueryStore -> OpsManager -> Spy -> [ExpressRoute]
module.exports = (query-store, ops-manager, {record-req}) ->

    {
        delete-branch
        delete-query
        get-branches
        get-latest-query-in-branch
        get-queries
        get-query-by-id
        get-query-version-history
        get-tags
        save-query
    } = query-store

    # Res -> Error -> Void
    die = (res, err) !->
        console.log "DEAD BECAUSE OF ERROR:", err
        res.status 500 .send err

    generate-user-id-and-session =
        methods: <[use]>
        request-handler: (req, res, next) ->
            current-time = Date.now!

            # user id (ensure that it is always an integer)                
            user-id = 
                | !!req.cookies.user-id => parse-int req.cookies.user-id
                | _ =>
                    res.cookie \userId, current-time, {maxAge: 100 * 365 * 24 * 60 * 60 * 1000, httpOnly: false}
                    current-time

            # session id (ensure that it is always an integer)        
            session-id = 
                | !!req.cookies.session-id => parse-int req.cookies.session-id
                | _ => 
                    res.cookie \sessionId, current-time, {httpOnly: false} 
                    current-time

            req <<< {user-id, session-id}
            next!

    parse-query-string =
        methods: <[use]>
        request-handler: (req, res, next) ->
            if req.query
                req.parsed-query = query-parser req.query 
            next!

    restrict-post-body-size =
        methods: <[use]>
        request-handler: (req, res, next) ->
            if req.method == \POST
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

    static-directories = 
        *   methods: <[use]>
            patterns: <[/public]>
            request-handler: express.static "#__dirname/public/"

        *   methods: <[use]>
            patterns: <[/node_modules]>
            request-handler: express.static "#__dirname/node_modules/"

    # solves 404 errors
    non-existant-snapshots = 
        methods: <[get]>
        patterns: <[/public/snapshots/*]>
        request-handler: (, res) ->
            res.status \content-type, \image/png
            res.end!

    # render index.html
    routes-that-render-index-html = 
        methods: <[get]>
        patterns: <[
            / 
            /branches 
            /branches/:branchId/queries/:queryId
            /branches/:branchId/queries/:queryId/diff
            /branches/:branchId/queries/:queryId/tree
            /creatives
            /import
            /ops
        ]>
        request-handler: (req, res) !->

            # impression id increments every time the user visits these routes
            impression-id = 
                | !!req.cookies?.impression-id => (parse-int req.cookies.impression-id) + 1
                | _ => 1
            res.cookie \impressionId, impression-id, {httpOnly: false}

            # record visit event
            record-req do 
                req
                user-id: req.user-id
                session-id: req.session-id
                impression-id: impression-id
                event-type: \visit

            viewbag = {req.user-id, req.session-id, impression-id}
            res.render \public/index.html, {viewbag}

    # render-query :: ExpressResponse -> p Query -> ()
    render-query = (res, query-p) !->
        err, {branch-id, query-id} <- to-callback query-p
        if err then die res, err else res.redirect "/branches/#{branch-id}/queries/#{query-id}"

    redirects = 
        *   methods: <[get]>
            patterns: <[/branches/:branchId]>
            request-handler: (req, res) ->
                render-query res, (get-latest-query-in-branch req.params.branch-id)

        *   methods: <[get]>
            patterns: <[/queries/:queryId]>
            request-handler: (req, res) ->
                render-query res, (get-query-by-id req.params.query-id)
        ...
    
    # send :: ExpressResponse -> p object -> ()
    send = (response, promise) !->
        err, result <- to-callback promise
        if err then die response, err else response.send result

    # returns a list of branches where each item has the branch-id and the latest-query in that branch
    branches = 
        methods: <[get]>
        patterns: <[/apis/branches]>
        request-handler: (req, res) ->
            send res, get-branches!

    # information about a single branch 
    branch-details = 
        methods: <[get]>
        patterns: <[/apis/branches/:branchId]>
        request-handler: (req, res) ->
            send do 
                res
                get-branches req.params.branch-id .then ([branch]?) -> branch ? {}

    cancel-op = 
        methods: <[get]>
        patterns: <[/apis/ops/:opId/cancel]>
        request-handler: (req, res) ->
            [err, op] = ops-manager.cancel-op req.params.op-id
            if err then die res, err else res.end \cancelled 

    connections = 
        methods: <[get]>
        patterns: <[/apis/queryTypes/:queryType/connections]>
        request-handler: (req, res) ->
            send do 
                res
                (require "./query-types/#{req.params.query-type}").connections req.query

    # returns the default document of query type identified by config.default-data-source.type
    default-document =  
        methods: <[post]>
        patterns: <[/apis/defaultDocument]>
        request-handler: (req, res) ->
            [data-source-cue, transpilation-language] = req.body
            {default-document} = require "./query-types/#{data-source-cue.query-type}"
            res.send {} <<< (default-document data-source-cue, transpilation-language) <<<
                data-source-cue: data-source-cue
                query-title: 'Untitled query'
                tags: []
                transpilation:
                    query: transpilation-language
                    transformation: transpilation-language
                    presentation: transpilation-language

    # sets the status property of all the queries in the branch to false
    delete-branch = 
        methods: <[get]>
        patterns: <[/apis/branches/:branchId/delete]>
        request-handler: (req, res) ->
            send res, (query-store.delete-branch req.params.branch-id)

    # sets the status property of th query to false
    delete-query = 
        methods: <[get]>
        patterns: <[
            /apis/queries/:queryId/delete
            /apis/branches/:branchId/queries/:queryId/delete
        ]>
        request-handler: (req, res) ->
            send res, (query-store.delete-query req.params.query-id)

    execute-post = 
        methods: <[post]>
        patterns: <[/apis/execute]>
        request-handler: (req, res) ->

            # pattern match the required fields
            {data-source-cue, query, transpilation-language, compiled-parameters, cache, op-id, op-info}? = req.body

            # convert document.data-source-cue to data-source used by the execute method
            {timeout}:data-source <- bindP (extract-data-source data-source-cue)

            # set the req / res timeout from data-source
            [req, res] |> each (.connection.set-timeout timeout ? 90000)

            # execute the query and emit the op-started on socket.io
            send do 
                res
                ops-manager.execute do 
                    query-store
                    data-source
                    query
                    transpilation-language
                    compiled-parameters
                    cache
                    op-id
                    {url: req.url} <<< op-info

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

    execute-query =
        methods: <[get]>
        patterns: <[
            /apis/branches/:branchId/execute
            /apis/queries/:queryId/execute
            /apis/branches/:branchId/queries/:queryId/execute
        ]>
        optional-params: <[cache display]>
        request-handler: (req, res) ->
            {branch-id, query-id, cache, display or \query}? = req.params
            cache = if !!cache then query-parser cache else false
            op-id = base62.encode Date.now!

            # Error -> (Res -> Void) -> Void
            err, render <- to-callback do ->

                # get the query from query-id (if present) otherwise get the latest query in the branch-id
                document <- bind-p do ->
                    if !!query-id
                        get-query-by-id query-id

                    else
                        get-latest-query-in-branch branch-id

                {
                    query-id
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
                {timeout}:data-source <- bind-p extract-data-source {} <<< data-source-cue <<< data-source-cue-params
                [req, res] |> each (.connection.set-timeout timeout ? 90000)

                # execute the query
                op-info = document
                {result} <- bind-p do 
                    ops-manager.execute do 
                        query-store
                        data-source
                        query
                        transpilation.query
                        compiled-parameters
                        cache
                        op-id
                        {url: req.url} <<< op-info

                switch display
                | \query => 
                    return-p (res) !-> res.send result

                | \transformation => 
                    transformation-function <- bind-p compile-transformation transformation, transpilation.transformation
                    return-p (res) !-> res.send (transformation-function result, compiled-parameters)

                | _ => 
                    return-p (res) !-> 
                        res.render \public/presentation/presentation.html, {
                            query-result: result
                            transpilation
                            transformation
                            presentation
                            compiled-parameters
                            client-external-libs
                        }

            if !!err then die res, err else render res
            
    # export a screenshot of the result
    export-query = 
        methods: <[get]>
        patterns: <[
            /apis/branches/:branchId/export
            /apis/queries/:queryId/export
            /apis/branches/:branchId/queries/:queryId/export
        ]>
        optional-params: <[cache format width height timeout]>
        request-handler: (req, res) ->
            {cache, format or 'png', width or 720, height or 480, timeout}? = req.params
            cache := if !!cache then query-parser cache else false
            {snapshot} = req.query

            # validate format
            text-formats = <[json text]>
            valid-formats = <[png]> ++ text-formats
            return die res, new Error "invalid format: #{format}, did you mean json?" if !(format in valid-formats)

            # find the query-id & title
            err, [data-source, document, parsed-query-string] <- to-callback do ->

                # use query-id if present, otherwise get the latest document for the given branch-id
                {data-source-cue}:document <- bind-p do ->
                    if req.params.query-id
                        get-query-by-id req.params.query-id

                    else
                        get-latest-query-in-branch req.params.branch-id

                # extract & separate data-source-cue from query-string
                [data-source-cue-params, parsed-query-string] = partition-data-source-cue-params req.parsed-query

                # extract data-source from data-source-cue (composed with data-source-cue-params extract from querystring above)
                data-source <- bind-p (extract-data-source {} <<< data-source-cue <<< data-source-cue-params)
                return-p [data-source, document, parsed-query-string]

            return die res, err if err

            {branch-id, query-id, query-title, query, transformation, transpilation} = document

            # client side name for the snapshot image or text/json/csv file, part of the response header
            filename = query-title.replace /\s/g, '_'

            if format in text-formats
                err, transformed-result <- to-callback do ->
                    [req, res] |> each (.connection.set-timeout data-source.timeout ? 90000)
                    {result} <- bind-p (ops-manager.execute do 
                        query-store
                        data-source
                        query
                        parsed-query-string
                        cache
                        query-id
                        {document, url: req.url}
                    )
                    transformed-result <- bind-p (transform result, transformation, parsed-query-string)
                    return-p transformed-result
                return die res, err if err

                download = (extension, content-type, content) ->
                    res.set \Content-disposition, "attachment; filename=#{filename}.#{extension}"
                    res.set \Content-type, content-type
                    res.end content

                match format
                | \json => download \json, \application/json, transformed-result
                | \text => download \txt, \text/plain, transformed-result

            else
                
                # server side name of the image file (composed of query-id or branch-id & current time)
                image-file = (
                    if snapshot 
                        "public/snapshots/#{branch-id}.png" 
                    else 
                        "tmp/#{branch-id}_#{query-id}_#{Date.now!}.png"
                )

                # create and setup phantom instance
                phantom-instance <- bind-p phantom.create!
                phantom-page <- bind-p phantom-instance.create-page!
                <- bind-p phantom-page.property \viewportSize, {width, height}
                <- bind-p phantom-page.property \clipRect, {width, height}

                # if this is a snapshot, then get the parameters from the document, otherwise use the querystring
                err, query-params <- to-callback do -> 
                    if snapshot
                        compile-parameters document.parameters, transpilation.query, {}
                    else 
                        return-p req.query
                return die res, err if err

                # load the page in phantom
                <- bind-p phantom-page.open do 
                    "http://127.0.0.1:#{http-port}/apis/queries/#{query-id}/execute/#{cache}/presentation" +
                    querystring.stringify query-params

                # give the page time to settle in before taking a screenshot
                <- set-timeout _, timeout ? (config?.snapshot-timeout ? 1000)
                <- bind-p phantom-page.render image-file

                if snapshot
                    res.end "snapshot saved to #{image-file}"

                # tell the browser to download the file
                else
                    res.set \Content-disposition, "attachment; filename=#{filename}.png"
                    res.set \Content-type, \image/png
                    create-read-stream image-file .pipe res

                phantom-instance.exit!

    import-data = 
        methods: <[post]>
        patterns: <[/apis/queryTypes/:queryType/import]>
        request-handler: (req, res) ->
            
            upload = (data-source-cue, parser, file) ->
                {timeout}:data-source <- bind-p (extract-data-source data-source-cue)
                [req, res] |> each (.connection.set-timeout timeout ? 90000)
                (require "./query-types/#{req.params.query-type}").import-stream file, parser, data-source, res

            doc = null
            busboy = new Busboy headers: req.headers
                ..on \file, (fieldname, file, filename, encoding, mimetype) ->
                    upload doc.data-source-cue, doc.parser, file
                        ..then (result) ->
                            res.send result

                        ..catch (error) ->
                            res.send error: error.toString!
                            req.destroy!
                    
                ..on \field, (fieldname, val) ->
                    if "doc" == fieldname
                        doc := JSON.parse val

            res.set \Content-type, \application/json
            res.set \Transfer-Encoding, \chunked
            req.pipe busboy


    keywords = 
        methods: <[post]>
        patterns: <[/apis/keywords]>
        request-handler: (req, res) ->
            [data-source-cue, ...rest] = req.body
            send do 
                res 
                extract-data-source data-source-cue .then ({query-type}:data-source) ->
                    (require "./query-types/#{query-type}").keywords [data-source] ++ rest

    ops = 
        methods: <[get]>
        patterns: <[/apis/ops]>
        request-handler: (req, res) -> 
            res.send ops-manager.running-ops!

    # returns all the data about a query 
    query-details = 
        methods: <[get]>
        patterns: <[
            /apis/queries/:queryId 
            /apis/branches/:branchId/queries/:queryId
        ]>
        request-handler: (req, res) ->
            send res, (get-query-by-id req.params.query-id)

    query-version-history = 
        methods: <[get]>
        patterns: <[/apis/queries/:queryId/tree]>
        request-handler: (req, res) ->
            err, history <- to-callback get-query-version-history req.params.query-id
            if err
                die res, err 
            else
                res.send do
                    history |> map ({query-id, creation-time}:commit) ->
                        {} <<< commit <<< 
                            selected: query-id == req.params.query-id
                            creation-time: moment creation-time .format "ddd, DD MMM YYYY, hh:mm:ss a"

    save-query = 
        methods: <[post]>
        patterns: <[/apis/save]>
        request-handler: (req, res) ->
            send res, (query-store.save-query req.body)

    tags = 
        methods: <[get]>
        patterns: <[\/apis/tags]>
        request-handler :(, res) ->
            send res, get-tags!

    api-routes =
        * branches
        * branch-details
        * cancel-op
        * connections
        * default-document 
        * delete-branch
        * delete-query
        * execute-query
        * execute-post
        * export-query
        * import-data
        * keywords
        * ops
        * query-details
        * query-version-history
        * save-query
        * tags

    [generate-user-id-and-session, parse-query-string, restrict-post-body-size] ++ 
    static-directories ++ 
    [non-existant-snapshots] ++ 
    routes-that-render-index-html ++ 
    redirects ++ 
    api-routes