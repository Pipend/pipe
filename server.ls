{bindP, from-error-value-callback, new-promise, returnP, to-callback} = require \./async-ls
body-parser = require \body-parser
{http-port, mongo-connection-opitons, query-database-connection-string}:config = require \./config
express = require \express
{create-read-stream, readdir} = require \fs
md5 = require \MD5
{MongoClient} = require \mongodb
{any, difference, each, filter, find, find-index, group-by, id, map, maximum-by, Obj, obj-to-pairs, pairs-to-obj, reject, sort-by, values} = require \prelude-ls
phantom = require \phantom
url-parser = (require \url).parse
querystring = require \querystring
{execute, transform, fill-data-source, compile-parameters, get-query-by-id, get-latest-query-in-branch, cancel-op, running-ops} = require \./utils

err, query-database <- MongoClient.connect query-database-connection-string, mongo-connection-opitons
return console.log "unable to connect to #{query-database-connection-string}: #{err.to-string!}" if !!err
console.log "successfully connected to #{query-database-connection-string}"

err, files <- readdir \./query-types
console.log err.to-string! if !!err
query-types = (files or [])
    |> reject -> it in <[default-query-context.ls]>
    |> map -> [(it.replace \.ls, ''), require "./query-types/#{it}"]
    |> pairs-to-obj

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

# render index.html
<[
    \/ 
    \/branches 
    \/branches/:branchId/queries/:queryId
    \/branches/:branchId/queries/:queryId/diff
]> |> each (route) ->
    app.get route, (req, res) -> res.render \public/index.html

# redirects you to the latest query in the branch i.e /branches/branchId/queries/queryId
app.get \/branches/:branchId, (req, res) ->
    err, {query-id, branch-id}? <- to-callback (get-latest-query-in-branch query-database, req.params.branch-id)
    return die res, err if !!err

    res.redirect "/branches/#{branch-id}/queries/#{query-id}"

# redirects you to /branches/:branchId/queries/queryId
app.get \/queries/:queryId, (req, res) ->
    err, {query-id, branch-id}? <- to-callback (get-query-by-id query-database, req.params.query-id)
    return die res, err if !!err

    res.redirect "/branches/#{branch-id}/queries/#{query-id}"

app.get \/apis/defaultDocument, (req, res) ->
    {type} = config.default-data-source
    res.end JSON.stringify {} <<< query-types[type].default-document! <<< {data-source: config.default-data-source, query-title: 'Untitled query'}

app.get \/apis/branches, (req, res) ->
    err, files <- readdir \public/snapshots
    
    err, results <- query-database.collection \queries .aggregate do 
        * $match: status: true
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
    res.end JSON.stringify do 
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
        null
        4

app.get \/apis/queries, (req, res) ->
    err, results <- query-database.collection \queries .aggregate do
        * $sort: _id: (req.parsed-query?.sort-order or 1)
        * $limit: (req.parsed-query?.limit) or 100
    return die res, err if !!err
    res.end JSON.stringify results, null, 4

app.get \/apis/queries/:queryId, (req, res) ->
    err, document <- to-callback (get-query-by-id query-database, req.params.query-id)
    return die res, err if !!err
    res.end JSON.stringify document

# set the status property of all the queries in the branch to false
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
    return die res, err if !!err

    res.end parent-id.0

# api :: delete query (by setting status prop to false)
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

app.post \/apis/execute, (req, res) ->
    {op-id, document:{data-source, query, parameters}}? = req.body
    err, result <- to-callback (execute query-database, data-source, query, parameters, false, op-id)
    if !!err then die res, err else res.end JSON.stringify result

# api :: execute query
<[
    /apis/branches/:branchId/execute
    /apis/queries/:queryId/execute
    /apis/branches/:branchId/queries/:queryId/execute
]> |> each (route) ->
    app.get route, (req, res) ->
        {branch-id, query-id}? = req.params
        {display or \query, cache or false}? = req.parsed-query

        pretty = -> JSON.stringify it, null, 4

        err, f <- to-callback do ->

            # get the query from query-id (if present) otherwise get the latest query in the branch-id
            {query-id, data-source, query, transformation, presentation} <- bindP do ->
                return (get-query-by-id query-database, query-id) if !!query-id
                get-latest-query-in-branch query-database, branch-id

            parameters = {} <<< req.parsed-query

            query-result <- bindP (execute query-database, data-source, query, parameters, cache, query-id)
            return returnP ((res) -> res.end pretty query-result) if display == \query

            transformed-result <- bindP (transform query-result, transformation, parameters)
            return returnP ((res) -> res.end pretty transformed-result) if display == \transformation

            returnP ((res) -> res.render \public/presentation/presentation.html, {presentation, transformed-result, parameters})

        if !!err then die res, err else f res

app.get \/apis/ops, (req, res) ->
    res.end JSON.stringify running-ops!

app.get \/apis/ops/:opId/cancel, (req, res) ->
    console.log \op-to-cancel, req.params.op-id
    cancel-op req.params.op-id
    res.end!

# api :: export query
<[
    /apis/branches/:branchId/export
    /apis/queries/:queryId/export
    /apis/branches/:branchId/queries/:queryId/export
]> |> each (route) ->
    app.get route, (req, res) ->
        {format or 'png', width or 720, height or 480} = req.query

        # validate format
        text-formats = <[json text]>
        valid-formats = <[png]> ++ text-formats
        return die res, new Error "invalid format: #{format}, did you mean json?" if !(format in valid-formats)

        # find the query-id & title
        err, {data-source, branch-id, query-id, query-title, query, transformation, parameters}? <- to-callback do ->
            return (get-query-by-id query-database, req.params.query-id) if !!req.params.query-id
            get-latest-query-in-branch query-database, req.params.branch-id
        return die res, err if !!err

        filename = query-title.replace /\s/g, '_'

        if format in text-formats
            parameters = {} <<< req.parsed-query
                |> obj-to-pairs
                |> reject ([key]) -> key in <[format width height]>
                |> pairs-to-obj
            
            err, transformed-result <- to-callback do ->
                query-result <- bindP (execute query-database, data-source, query, parameters, false, query-id)
                transformed-result <- bindP (transform query-result, transformation, parameters)
                returnP transformed-result
            return die res, err if !!err

            download = (extension, content-type, content) ->
                return res.end! if req.query.snapshot
                res.set \Content-disposition, "attachment; filename=#{filename}.#{extension}"
                res.set \Content-type, content-type
                res.end content

            match format
            | \json => download \json, \application/json, JSON.stringify transformed-result, null, 4
            | \text => download \txt, \text/plain, JSON.stringify transformed-result, null, 4

        else
            # use the query-id for naming the file
            image-file = if req.query.snapshot then "public/snapshots/#{branch-id}.png" else "tmp/#{branch-id}_#{query-id}_#{Date.now!}.png"
            {create-page, exit} <- phantom.create
            {open, render}:page <- create-page
            page.set \viewportSize, {width, height}
            page.set \onLoadFinished, ->
                page.evaluate do 
                    ->
                        # crop the result
                        document.body.children.0.style <<< {
                            width: "#{window.inner-width}px"
                            height: "#{window.inner-height}px"
                            overflow: \hidden
                        }
                    ->
                        <- render image-file
                        res.set \Content-disposition, "attachment; filename=#{filename}.png"
                        res.set \Content-type, \image/png
                        if req.query.snapshot then res.end! else (create-read-stream image-file .pipe res)
                        exit!   

            # compose the url for executing the query
            base-url = url-parser req.url .pathname .replace \/export, \/execute
            err, query-params <- to-callback do ->
                if req.query.snapshot
                    compile-parameters data-source.type, parameters
                else
                    returnP req.query
                        |> obj-to-pairs
                        |> reject ([key]) -> key in <[format width height]>
                        |> pairs-to-obj
            qs = querystring.stringify {} <<< query-params <<< {display: \presentation, cache: \false}
            open "http://127.0.0.1:#{http-port}#{base-url}?#{qs}"

# save the code to mongodb
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

        return die res, JSON.stringify {queries-in-between}
    
    err, records <- query-database.collection \queries .insert req.body <<< {user: req.user, creation-time: new Date!.get-time!, status: true}, {w: 1}
    return die res, err if !!err

    res.set \Content-Type, \application/json
    res.status 200 .end JSON.stringify records.0

app.get \/apis/queryTypes/:queryType/connections, (req, res) ->
    err, result <- to-callback (query-types[req.params.query-type].connections req.query)
    return die res, err if !!err

    res.end JSON.stringify result

app.post \/apis/queryTypes/:queryType/keywords, (req, res) ->
    err, result <- to-callback (query-types[req.params.query-type].keywords fill-data-source req.body)
    return die res, err if !!err

    res.end JSON.stringify result

app.listen http-port
console.log "listening for connections on port: #{http-port}"
