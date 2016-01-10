{bind-p, from-error-value-callback, new-promise, return-p, to-callback} = require \./async-ls
require! \base62
require! \body-parser
Busboy = require \busboy

# config
{file-streams, http-port, mongo-connection-opitons, project-title, 
query-database-connection-string, redis-channels, socket-io-port, snapshot-server}:config = require \./config

require! \express
{create-read-stream, readdir} = require \fs
require! \moment
{MongoClient} = require \mongodb
{record-req}? = (require \pipend-spy) config?.spy?.storage-details

# prelude
{any, camelize, difference, each, filter, find, find-index, fold, group-by, id, map, maximum-by, 
Obj, obj-to-pairs, pairs-to-obj, partition, reject, Str, sort, sort-by, unique, values} = require \prelude-ls

require! \phantom
url-parser = (require \url).parse
require! \querystring
require! \redis

# utils
{transform, extract-data-source, compile-parameters, get-query-by-id, 
get-latest-query-in-branch, get-op, cancel-op, running-ops, ops-manager}:utils = require \./utils

err, query-database <- MongoClient.connect query-database-connection-string, mongo-connection-opitons
return console.log "unable to connect to #{query-database-connection-string}: #{err.to-string!}" if !!err
console.log "successfully connected to #{query-database-connection-string}"

{compile-parameters, compile-transformation} = require \pipe-transformation

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

app = express!
    ..set \views, __dirname + \/
    ..engine \.html, (require \ejs).__express
    ..set 'view engine', \ejs
    ..use (require \cors)!
    ..use (require \serve-favicon) __dirname + '/public/images/favicon.png'
    ..use (require \cookie-parser)!    
    ..use (req, res, next) ->

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

    ..use (req, res, next) ->
        req.parsed-query = query-parser req.query if !!req.query
        next!
    ..use (req, res, next) ->
        return next! if (req.method is not \POST or ((req.url.index-of "apis") > 0 and (req.url.index-of "/import") > 0))
        body = ""
        size = 0
        req.on \data, -> 
            size += it.length
            if size > 4e6
                res.write-head 413, 'Connection': 'close'
                res.end "File size exceeded"
            body += it 
        req.on \end, ->
            req <<< {body: JSON.parse body}
            next!
    ..use "/public" express.static "#__dirname/public/"
    ..use "/node_modules" express.static "#__dirname/node_modules/"

    # solves 404 errors
    ..get \/public/snapshots/*, (req, res) -> 
        res.status \content-type, \image/png
        res.end!



# Res -> Error -> Void
die = (res, err) !->
    console.log "DEAD BECAUSE OF ERROR: #{err.to-string!}"
    res.status 500 .end err.to-string!

# with-optional-params :: [String] -> [String] -> [String]
with-optional-params = (routes, params) -->
    routes 
        |> fold do 
            (acc, value) ->
                new-routes = [0 to params.length]
                    |> map (i) ->
                        [0 til i] 
                            |> map -> ":#{params[it]}"
                            |> Str.join \/
                    |> map -> "#{value}/#{it}"
                acc ++ new-routes
            []

pretty = -> JSON.stringify it, null, 4
json = -> JSON.stringify it

# render index.html
<[
    \/ 
    \/branches 
    \/branches/:branchId/queries/:queryId
    \/branches/:branchId/queries/:queryId/diff
    \/branches/:branchId/queries/:queryId/tree
    \/creatives
    \/import
    \/ops
]> |> each (route) ->
    app.get route, (req, res) -> 

        # impression id increments every time the user visits these routes
        impression-id = 
            | !!req.cookies?.impression-id => (parse-int req.cookies.impression-id) + 1
            | _ => 1
        res.cookie \impressionId, impression-id, {httpOnly: false}

        # record visit event
        if !!record-req and !!config?.spy?.enabled
            record-req do 
                req
                user-id: req.user-id
                session-id: req.session-id
                impression-id: impression-id
                event-type: \visit
        
        viewbag = {req.user-id, req.session-id, impression-id, project-title}
        res.render \public/index.html, {viewbag}

# redirects you to the latest query in the branch i.e /branches/branchId/queries/queryId
app.get \/branches/:branchId, (req, res) ->
    err, {query-id, branch-id}? <- to-callback (get-latest-query-in-branch query-database, req.params.branch-id)
    if !!err then die res, err else res.redirect "/branches/#{branch-id}/queries/#{query-id}"

# redirects you to /branches/:branchId/queries/queryId
app.get \/queries/:queryId, (req, res) ->
    err, {query-id, branch-id}? <- to-callback (get-query-by-id query-database, req.params.query-id)
    if !!err then die res, err else res.redirect "/branches/#{branch-id}/queries/#{query-id}"

# api :: default-document
# returns the default document of query type identified by config.default-data-source.type
# /apis/defaultDocuemnt
app.post \/apis/defaultDocument, (req, res) ->
    [data-source-cue, transpilation-language] = req.body
    {default-document} = require "./query-types/#{data-source-cue.query-type}"
    res.end pretty {} <<< (default-document data-source-cue, transpilation-language) <<<
        data-source-cue: data-source-cue
        query-title: 'Untitled query'
        tags: []
        transpilation:
            query: transpilation-language
            transformation: transpilation-language
            presentation: transpilation-language

# api :: list of branches
# returns a list of branches where each item has the branch-id and the latest-query in that branch
# /apis/branches
# /apis/branches/:branchId 
<[
    /apis/branches
    /apis/branches/:branchId
]> |> each (route) ->
    app.get route, (req, res) ->
        err, files <- readdir \public/snapshots
        err, results <- query-database.collection \queries .aggregate do 
            * $match: {status: true} <<< (if !!req.params.branch-id  then {branch-id: req.params.branch-id} else {})
            * $sort: _id : 1
            * $group: 
                _id: \$branchId
                branch-id: $last: \$branchId
                query-id: $last: \$queryId
                query-title: $last: \$queryTitle
                data-source-cue: $last: \$dataSourceCue
                presentation: $last: \$presentation
                tags: $last: \$tags
                user: $last: \$user
                creation-time: $last: \$creationTime
            * $project:
                _id: 0
                branch-id: 1
                query-id: 1
                query-title: 1
                data-source-cue: 1
                tags: 1
                user: 1
                creation-time: 1

        return die res, err if !!err
        res.set \Content-type, \application/json
        res.end pretty do 
            results
                |> map ({branch-id}:latest-query) -> 
                    {
                        branch-id
                        latest-query
                        snapshot: "#{snapshot-server}/public/snapshots/#{branch-id}.png"
                    }
                |> sort-by (.latest-query.creation-time * -1)

# api :: list of queries
# returns a list of queries optionally filtered by branch-id 
# /apis/queries?sort=1&limit=100
# /apis/branches/:branchId/queries?sort=-1&limit=100
<[
    /apis/queries
    /apis/branches/:branchId/queries
]> |> each (route) ->
    app.get route, (req, res) ->
        pipeline =
            * $sort: _id: (req.parsed-query?.sort-order or 1)
            * $limit: (req.parsed-query?.limit) or 100
        err, results <- query-database.collection \queries .aggregate do
            (if !!req.params.branch-id then [$match: branch-id: req.params.branch-id] else []) ++ pipeline
        if !!err then die res, err else res.end pretty results

app.get \/apis/queries/:queryId/tree, (req, res) ->
    err, results <- query-database.collection \queries .aggregate do 
        * $match:
            query-id: req.params.query-id
            status: true
        * $project:
            tree-id: 1
    return die res, err if !!err
    return die res, "unable to find query #{req.params.query-id}" if results.length == 0
    err, results <- query-database.collection \queries .aggregate do 
        * $match:
            tree-id: results.0.tree-id
            status: true
        * $sort: _id: 1
        * $project:
            parent-id: 1
            branch-id: 1
            query-id: 1
            query-title: 1
            creation-time: 1
            selected: $eq: [\$queryId, req.params.query-id]
    return die res, err if !!err
    res.end pretty do 
        results 
            |> map ({creation-time}: query)-> {} <<< query <<< {creation-time: moment creation-time .format "ddd, DD MMM YYYY, hh:mm:ss a"}

# api :: query details
# returns all the data about a query 
# /apis/queries/:queryId
# /apis/branches/:branchId/queries/:queryId
<[
    /apis/queries/:queryId
    /apis/branches/:branchId/queries/:queryId
]> |> each (route) ->
    app.get route, (req, res) ->
        err, document <- to-callback (get-query-by-id query-database, req.params.query-id)
        if !!err then die res, err else res.end pretty document

# api :: delete branch
# sets the status property of all the queries in the branch to false
# /apis/branches/:branchId/delete
app.get "/apis/branches/:branchId/delete", (req, res)->

    (err, results) <- query-database.collection \queries .aggregate do 
        * $match: 
            branch-id: req.params.branch-id
        * $project:
            query-id: 1
            parent-id: 1
    return die res, err if !!err
    
    parent-id = difference do
        results |> map (.parent-id)
        results |> map (.query-id)

    # set the status of all queries in the branch to false i.e delete 'em all
    (err) <- query-database.collection \queries .update {branch-id: req.params.branch-id}, {$set: {status: false}}, {multi: true}
    return die res, err if !!err

    # reconnect the children to the parent of the branch
    criterion =
        $and: 
            * branch-id: $ne: req.params.branch-id
            * parent-id: $in: results |> map (.query-id)
    (err, queries-updated) <- query-database.collection \queries .update criterion, {$set: {parent-id: parent-id.0}}, {multi:true}
    if !!err then die res, err else res.end parent-id.0

# api :: delete query 
# sets the status property of th query to false
# /apis/queries/:queryId/delete
# /apis/branches/:branchId/queries/:queryId/delete
<[
    /apis/queries/:queryId/delete
    /apis/branches/:branchId/queries/:queryId/delete
]> |> each (route) ->
    app.get route, (req, res) ->
        err, results <- query-database.collection \queries .aggregate do 
            * $match:
                query-id: req.params.query-id
        return die res, err if !!err
        
        err <- query-database.collection \queries .update {query-id: req.params.query-id}, {$set: {status: false}}
        return die res err if !!err

        err, queries-updated <- query-database.collection \queries .update {parent-id: req.params.query-id}, {$set: {parent-id: results.0.parent-id}}, {multi:true}
        return die res err if !!err

        res.end results.0.parent-id

# api :: execute query
# executes the query object present in req.body
# /apis/execute
app.post \/apis/execute, (req, res) ->

    # pattern match the required fields
    {data-source-cue, query, transpilation-language, compiled-parameters, cache, op-id, op-info}? = req.body

    # convert document.data-source-cue to data-source used by the execute method
    {timeout}:data-source <- bindP (extract-data-source data-source-cue)

    # set the req / res timeout from data-source
    [req, res] |> each (.connection.set-timeout timeout ? 90000)

    err, result <- to-callback do ->

        # execute the query and emit the op-started on socket.io
        ops-manager.execute do 
            query-database
            data-source
            query
            transpilation-language
            compiled-parameters
            cache
            op-id
            {url: req.url} <<< op-info

    if !!err then die res, err else res.end json result

# partition-data-source-cue-params :: ParsedQueryString -> Tuple DataSourceCueParams ParsedQueryString
partition-data-source-cue-params = (query) ->
    query
        |> obj-to-pairs 
        |> partition (0 ==) . (.0.index-of 'dsc-') 
        |> ([ds, qs]) -> 
            [(ds |> map ([k,v]) -> [(camelize k.replace /^dsc-/, ''),v]), qs] 
                |> map pairs-to-obj

# api :: execute query
# retrieves the query from query-id or branch-id and returns the execution result
# /apis/branches/:branchId/execute
# /apis/branches/:branchId/execute/:cache
# /apis/branches/:branchId/execute/:cache/:display
<[
    /apis/branches/:branchId/execute
    /apis/queries/:queryId/execute
    /apis/branches/:branchId/queries/:queryId/execute
]> `with-optional-params` <[cache display]> |> each (route) ->
    app.get route, (req, res) ->
        {branch-id, query-id, cache, display or \query}? = req.params
        cache = if !!cache then query-parser cache else false
        op-id = base62.encode Date.now!

        # Error -> (Res -> Void) -> Void
        err, render <- to-callback do ->

            # get the query from query-id (if present) otherwise get the latest query in the branch-id
            {query-id, data-source-cue, transpilation, query, transformation, presentation, client-external-libs}:document <- bind-p do ->
                if !!query-id
                    get-query-by-id query-database, query-id

                else
                    get-latest-query-in-branch query-database, branch-id

            # user can override PartialDataSource properties by providing ds- parameters in the query string
            [data-source-cue-params, compiled-parameters] = partition-data-source-cue-params req.parsed-query 

            # req/res timeout
            {timeout}:data-source <- bind-p extract-data-source {} <<< data-source-cue <<< data-source-cue-params
            [req, res] |> each (.connection.set-timeout timeout ? 90000)

            # execute the query
            op-info = document
            {result} <- bind-p do 
                ops-manager.execute do 
                    query-database
                    data-source
                    query
                    transpilation.query
                    compiled-parameters
                    cache
                    op-id
                    {url: req.url} <<< op-info

            switch display
            | \query => 
                return-p (res) !-> res.end json result

            | \transformation => 
                transformation-function <- bind-p compile-transformation transformation, transpilation.transformation
                return-p (res) !-> res.end json (transformation-function result, compiled-parameters)

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

# api :: running ops
app.get \/apis/ops, (req, res) ->
    res.end pretty ops-manager.running-ops!

# api :: cancel op
app.get \/apis/ops/:opId/cancel, (req, res) ->
    [err, op] = ops-manager.cancel-op req.params.op-id
    if !!err then die res, err else res.end \cancelled 

# api :: export query
# export a screenshot of the result
# /apis/branches/:branchId/export
# /apis/branches/:branchId/export/:cache
# /apis/branches/:branchId/export/:cache/:format
# /apis/branches/:branchId/export/:cache/:format/:width
# /apis/branches/:branchId/export/:cache/:format/:width/:height
<[
    /apis/branches/:branchId/export
    /apis/queries/:queryId/export
    /apis/branches/:branchId/queries/:queryId/export
]> `with-optional-params` <[cache format width height timeout]> |> each (route) ->
    app.get route, (req, res) ->
        {cache, format or 'png', width or 720, height or 480, timeout}? = req.params
        cache := if !!cache then query-parser cache else false
        {snapshot} = req.query

        # validate format
        text-formats = <[json text]>
        valid-formats = <[png]> ++ text-formats
        return die res, new Error "invalid format: #{format}, did you mean json?" if !(format in valid-formats)

        # find the query-id & title
        err, [data-source, {branch-id, query-id, query-title, query, transformation}:document, parsed-query-string] <- to-callback do ->
            {data-source-cue}:document <- bind-p do ->
                return (get-query-by-id query-database, req.params.query-id) if !!req.params.query-id
                get-latest-query-in-branch query-database, req.params.branch-id
            [data-source-cue-params, parsed-query-string] = partition-data-source-cue-params req.parsed-query
            data-source <- bind-p (extract-data-source {} <<< data-source-cue <<< data-source-cue-params)
            return-p [data-source, document, parsed-query-string]
        return die res, err if !!err

        filename = query-title.replace /\s/g, '_'

        if format in text-formats
            err, transformed-result <- to-callback do ->
                [req, res] |> each (.connection.set-timeout data-source.timeout ? 90000)
                {result} <- bind-p (ops-manager.execute query-database, data-source, query, parsed-query-string, cache, query-id, {document, url: req.url})
                transformed-result <- bind-p (transform result, transformation, parsed-query-string)
                return-p transformed-result
            return die res, err if !!err

            download = (extension, content-type, content) ->
                res.set \Content-disposition, "attachment; filename=#{filename}.#{extension}"
                res.set \Content-type, content-type
                res.end content

            match format
            | \json => download \json, \application/json, pretty transformed-result
            | \text => download \txt, \text/plain, pretty transformed-result

        else
            # use the query-id for naming the file
            image-file = if snapshot then "public/snapshots/#{branch-id}.png" else "tmp/#{branch-id}_#{query-id}_#{Date.now!}.png"
            {create-page, exit} <- phantom.create
            {open, render}:page <- create-page
            page.set \viewportSize, {width, height}
            page.set \onLoadFinished, ->
                page.evaluate do 
                    ->
                        document.body.children.0.style <<< {
                            width: "#{window.inner-width}px"
                            height: "#{window.inner-height}px"
                            overflow: \hidden
                        }
                    ->
                        <- set-timeout _, timeout ? (config?.snapshot-timeout ? 1000)
                        <- render image-file
                        if snapshot
                            res.end "snapshot saved to #{image-file}"
                        else
                            res.set \Content-disposition, "attachment; filename=#{filename}.png"
                            res.set \Content-type, \image/png
                            create-read-stream image-file .pipe res
                        exit!

            # compose the url for executing the query
            err, query-params <- to-callback do -> 
                if snapshot
                    compile-parameters data-source.query-type, document.parameters
                else 
                    return-p req.query
            open "http://127.0.0.1:#{http-port}/apis/queries/#{query-id}/execute/#{cache}/presentation?#{querystring.stringify query-params}"

# api :: save query
app.post \/apis/save, (req, res) ->

    err, results <- query-database.collection \queries .aggregate do 
        * $match:
            branch-id: req.body.branch-id
            status: true
        * $project:
            query-id: 1
            parent-id: 1
        * $sort: _id: -1
    return die res, err.to-string! if !!err

    if !!results?.0 and results.0.query-id != req.body.parent-id

        index-of-parent-query = results |> find-index (.query-id == req.body.parent-id)

        queries-in-between = [0 til results.length] 
            |> map -> [it, results[it].query-id]
            |> filter ([index])-> index < index-of-parent-query
            |> map (.1)

        return die res, pretty {queries-in-between}
    
    err, records <- query-database.collection \queries .insert req.body <<< {user: req.user, creation-time: new Date!.get-time!, status: true}, {w: 1}
    return die res, err if !!err

    res.set \Content-Type, \application/json
    res.status 200 .end pretty records.0

# api :: {{query-type}} connections
app.get \/apis/queryTypes/:queryType/connections, (req, res) ->
    err, result <- to-callback ((require "./query-types/#{req.params.query-type}").connections req.query)
    if !!err then die res, err else res.end pretty result

# api :: keywords
app.post \/apis/keywords, (req, res) ->
    err, result <- to-callback do ->
        [data-source-cue, ...rest] = req.body
        {query-type}:data-source <- bind-p (extract-data-source data-source-cue)
        (require "./query-types/#{query-type}").keywords [data-source] ++ rest
    if !!err then die res, err else res.end pretty result

# api :: tags
app.get \/apis/tags, (req, res) ->
    err, results <- query-database .collection \queries .aggregate do 
        * $match: tags: $exists: true 
        * $project: tags: 1
        * $unwind: \$tags
    res.end do 
        results
            |> map (.tags) >> (.to-lower-case!) >> (.trim!)
            |> unique
            |> sort
            |> -> JSON.stringify it

app.post \/apis/queryTypes/:queryType/import, (req, res) ->

    upload = (data-source-cue, parser, file) ->
        {timeout}:data-source <- bind-p (extract-data-source data-source-cue)
        [req, res] |> each (.connection.set-timeout timeout ? 90000)        
        (require "./query-types/#{query-type}").import-stream file, parser, data-source, res

    res.set 'Transfer-Encoding', 'chunked'
    res.set \Content-type, \application/json

    queryType = req.params.queryType
    doc = null

    exception = null
    busboy = new Busboy headers: req.headers
        ..on \file, (fieldname, file, filename, encoding, mimetype) ->
            console.log \file, fieldname, filename, encoding, mimetype
            console.log \doc, doc

            upload doc.data-source-cue, doc.parser, file
                ..then (result) ->
                    res.end <| JSON.stringify result

                ..catch (error) ->
                    res.end <| JSON.stringify error: error.toString!
                    req.destroy!

            
        ..on \field, (fieldname, val, fieldnameTruncated, valTruncated) ->
            console.log \field, fieldname, val, fieldnameTruncated, valTruncated
            if "doc" == fieldname
                doc := JSON.parse val

        busboy.on \finish, ->
            #res.end "finished"

    req.pipe busboy

server = app.listen http-port

console.log "listening for connections on port: #{http-port}"

# emit all the running ops to the client
io = (require \socket.io) server
    ..on \connect, (connection) ->
        connection.emit \ops, ops-manager.running-ops!

ops-manager.on \change, -> io.emit \ops, ops-manager.running-ops!

set-interval do 
    -> io.emit \ops, ops-manager.running-ops!
    1000
