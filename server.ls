{bindP, from-error-value-callback, new-promise, returnP, to-callback} = require \./async-ls
body-parser = require \body-parser
{http-port, mongo-connection-opitons, query-database-connection-string}:config = require \./config
express = require \express
{create-read-stream, readdir} = require \fs
md5 = require \MD5
moment = require \moment
{MongoClient} = require \mongodb
{any, difference, each, filter, find, find-index, fold, group-by, id, map, maximum-by, Obj, obj-to-pairs, pairs-to-obj, reject, Str, sort-by, values, partition, camelize} = require \prelude-ls
phantom = require \phantom
url-parser = (require \url).parse
querystring = require \querystring
{execute, transform, fill-data-source, compile-parameters, get-query-by-id, get-latest-query-in-branch, get-op, cancel-op, running-ops} = require \./utils

err, query-database <- MongoClient.connect query-database-connection-string, mongo-connection-opitons
return console.log "unable to connect to #{query-database-connection-string}: #{err.to-string!}" if !!err
console.log "successfully connected to #{query-database-connection-string}"

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
    ..use (require \cookie-parser)!
    ..use body-parser.json!
    ..use (req, res, next) ->        
        req.parsed-query = query-parser req.query if !!req.query
        next!
    ..use "/public" express.static "#__dirname/public/"
    ..use "/node_modules" express.static "#__dirname/node_modules/"

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
]> |> each (route) ->
    app.get route, (req, res) -> res.render \public/index.html

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
app.get \/apis/defaultDocument, (req, res) ->
    {type} = config.default-data-source
    res.end pretty {} <<< (require "./query-types/#{type}").default-document! <<< {data-source: config.default-data-source, query-title: 'Untitled query'}

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
            * $project:
                _id: 1
                branch-id: 1
                query-id: 1
                query-title: 1
                data-source: 1
                user: 1
                creation-time: 1
        return die res, err if !!err
        res.set \Content-type, \application/json
        res.end pretty do 
            results
                |> group-by (.branch-id)
                |> Obj.map maximum-by (.creation-time) 
                |> obj-to-pairs
                |> map ([branch-id, latest-query]) -> 
                    {
                        branch-id
                        latest-query
                        snapshot: (files or [])
                            |> find -> (it.index-of branch-id) == 0
                            |> -> if !it then null else "public/snapshots/#{it}"
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
    {op-id, document:{data-source:partial-data-source, query, parameters}, cache}? = req.body
    
    # get the complete data-source which includes the query-type
    {timeout}:data-source = fill-data-source partial-data-source
    [req, res] |> each (.connection.set-timeout timeout ? 90000)

    err, result <- to-callback (execute query-database, data-source, query, parameters, cache, op-id)
    if !!err then die res, err else res.end json result

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
        err, f <- to-callback do ->

            # get the query from query-id (if present) otherwise get the latest query in the branch-id
            {query-id, data-source, query, transformation, presentation} <- bindP do ->
                return (get-query-by-id query-database, query-id) if !!query-id
                get-latest-query-in-branch query-database, branch-id

            # user can override PartialDataSource properties by providing ds- parameters in the query string
            [partial-data-source-params, parameters] = req.parsed-query 
                |> obj-to-pairs 
                |> partition (0 ==) . (.0.index-of 'ds-') 
                |> ([ds, qs]) -> 
                    [(ds |> map ([k,v]) -> [(camelize k.replace /^ds-/, ''),v]), qs] 
                        |> map pairs-to-obj

            partial-data-source = {} <<< data-source <<< partial-data-source-params

            # get the complete data-source which includes the query-type
            {timeout}:data-source = fill-data-source partial-data-source
            [req, res] |> each (.connection.set-timeout timeout ? 90000)

            {result} <- bindP (execute query-database, data-source, query, parameters, cache, query-id)
            return returnP ((res) -> res.end json result) if display == \query

            transformed-result <- bindP (transform result, transformation, parameters)
            return returnP ((res) -> res.end json transformed-result) if display == \transformation

            returnP ((res) -> res.render \public/presentation/presentation.html, {presentation, transformed-result, parameters})

        if !!err then die res, err else f res

# api :: running ops
app.get \/apis/ops, (req, res) ->
    res.end pretty running-ops!

# api :: cancel op
app.get \/apis/ops/:opId/cancel, (req, res) ->
    [status, err] = cancel-op req.params.op-id
    if status then res.end \cancelled else die res, err

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
]> `with-optional-params` <[cache format width height]> |> each (route) ->
    app.get route, (req, res) ->        
        {cache, format or 'png', width or 720, height or 480} = req.params
        cache := if !!cache then query-parser cache else false
        {snapshot} = req.query

        # validate format
        text-formats = <[json text]>
        valid-formats = <[png]> ++ text-formats
        return die res, new Error "invalid format: #{format}, did you mean json?" if !(format in valid-formats)

        # find the query-id & title
        err, {data-source:partial-data-source, branch-id, query-id, query-title, query, transformation, parameters}? <- to-callback do ->
            return (get-query-by-id query-database, req.params.query-id) if !!req.params.query-id
            get-latest-query-in-branch query-database, req.params.branch-id
        return die res, err if !!err

        console.log \partial-data-source, partial-data-source

        # get the complete data-source which includes the query-type
        {timeout}:data-source = fill-data-source partial-data-source
        [req, res] |> each (.connection.set-timeout timeout ? 90000)

        filename = query-title.replace /\s/g, '_'

        if format in text-formats
            err, transformed-result <- to-callback do ->

                {result} <- bindP (execute query-database, data-source, query, req.parsed-query, cache, query-id)
                transformed-result <- bindP (transform result, transformation, req.parsed-query)
                returnP transformed-result
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
                        <- set-timeout _, 2000
                        <- render image-file
                        res.set \Content-disposition, "attachment; filename=#{filename}.png"
                        res.set \Content-type, \image/png
                        if snapshot then res.end! else (create-read-stream image-file .pipe res)
                        exit!   

            # compose the url for executing the query
            err, query-params <- to-callback do -> if snapshot then (compile-parameters data-source.type, parameters) else returnP req.query
            open "http://127.0.0.1:#{http-port}/apis/queries/#{query-id}/execute/#{cache}/presentation?#{querystring.stringify query-params}"

# api :: save query
app.post \/apis/save, (req, res)->

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

# api :: {{query-type}} keywords
app.post \/apis/queryTypes/:queryType/keywords, (req, res) ->
    err, result <- to-callback ((require "./query-types/#{req.params.query-type}").keywords fill-data-source req.body)
    if !!err then die res, err else res.end pretty result

app.listen http-port
console.log "listening for connections on port: #{http-port}"
