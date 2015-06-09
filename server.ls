{promises:{bindP, from-error-value-callback, new-promise, returnP, to-callback}} = require \async-ls
body-parser = require \body-parser
{http-port, mongo-connection-opitons, query-database-connection-string}:config = require \./config
express = require \express
{create-read-stream, readdir} = require \fs
md5 = require \MD5
{MongoClient} = require \mongodb
{any, each, filter, find-index, id, map, obj-to-pairs, pairs-to-obj, reject} = require \prelude-ls
{compile-and-execute-livescript} = require \./utils
transformation-context = require \./public/transformation/context
phantom = require \phantom
url-parser = (require \url).parse
querystring = require \querystring

query-cache = {}

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

<[
    \/ 
    \/branches 
    \/branches/:branchId/queries/:queryId
    \/branches/:branchId/queries/:queryId/diff
]> |> each (route) ->
    app.get route, (req, res) -> res.render \public/index.html

# DB -> String -> p Query
get-latest-query-in-branch = (query-database, branch-id) -->
    collection = query-database.collection \queries
    results <- bindP (from-error-value-callback collection.aggregate, collection) do 
        * $match: {branch-id,status: true}
        * $sort: _id: -1
    return returnP results.0 if !!results?.0
    new-promise (, rej) -> rej "unable to find any query in branch: #{branch-id}" 

# redirects you to the latest query in the branch i.e /branches/branchId/queries/queryId
app.get \/branches/:branchId, (req, res) ->
    err, {query-id, branch-id}? <- to-callback (get-latest-query-in-branch query-database, req.params.branch-id)
    return die res, err if !!err

    res.redirect "/branches/#{branch-id}/queries/#{query-id}"

# DB -> String -> p Query
get-query-by-id = (query-database, query-id) -->
    collection = query-database.collection \queries
    results <- bindP (from-error-value-callback collection.aggregate, collection) do 
        * $match: {query-id}
        * $sort: _id: - 1
        * $limit: 1
    return returnP results.0 if !!results?.0
    new-promise (, rej) -> rej "query not found #{query-id}"

# redirects you to /branches/:branchId/queries/queryId
app.get \/queries/:queryId, (req, res) ->
    err, {query-id, branch-id}? <- to-callback (get-query-by-id query-database, req.params.query-id)
    return die res, err if !!err

    res.redirect "/branches/#{branch-id}/queries/#{query-id}"

app.get \/apis/defaultDocument, (req, res) ->
    {type} = config.default-data-source
    res.end JSON.stringify {} <<< query-types[type].default-document! <<< {data-source: config.default-data-source, query-title: 'Untitled query'}

app.get \/apis/queries, (req, res) ->
    err, results <- query-database.collection \queries .aggregate do 
        * $limit: (req.parsed-query?.limit) or 100
        * $sort: _id: (req.parsed-query?.sort-order or 1)
    return die res, err if !!err
    res.end JSON.stringify results, null, 4

app.get \/apis/queries/:queryId, (req, res) ->
    err, document <- to-callback (get-query-by-id query-database, req.params.query-id)
    return die res, err if !!err
    res.end JSON.stringify document

# fill-data-source :: PartialDataSource -> DataSource
fill-data-source = (partial-data-source) ->
    connection-prime = config?.connections?[partial-data-source?.type][partial-data-source?.connection-name]
    data-source = {} <<< (connection-prime or {}) <<< partial-data-source

# execute :: PartialDataSource -> String -> QueryParameters -> Cache -> p Result
execute = (partial-data-source, query, parameters, cache) -->

    # compile-parameters :: (Promise p) => DataSource -> QueryParameters -> p CompiledQueryParameters
    compile-parameters = (data-source, paramaters) ->
        res, rej <- new-promise

        {type}? = data-source
        return rej new Error "query type: #{type} not found" if typeof query-types[type] == \undefined

        # parameters is String if coming from the single query interface; 
        # it is an empty object if coming from multi query interface
        if \String == typeof! parameters
            [err, parameters] = compile-and-execute-livescript parameters, query-types[type].get-context!
            return rej err if !!err

        res (parameters or {})

    # get-result :: (Promise p) => DataSource -> String -> QueryParameters -> p result
    get-result = ({type}:data-source, query, parameters, cache) ->
        
        compiled-query-parameters <- bindP (compile-parameters data-source, parameters)

        # return the cached result if any
        read-from-cache = [
            typeof cache == \boolean and cache === true
            typeof cache == \number and (new Date.value-of! - query-cache[key]?.time) / 1000 < cache
        ] |> any id        
        key = md5 JSON.stringify {data-source, type, query, compiled-query-parameters}
        return returnP query-cache[key] if read-from-cache and !!query-cache[key]
        
        # execute the query and return the result wrapped in a promise
        query-types[type].execute data-source, query, parameters, cache

    result <- bindP do 
        get-result (fill-data-source partial-data-source), query, parameters, cache
    # query-cache[key] := {result, time: new Date!.value-of!}
    returnP result

app.post \/apis/execute, (req, res) ->
    {document:{data-source, query, parameters}}? = req.body
    err, result <- to-callback (execute data-source, query, parameters, false)
    return die res, err if !!err

    res.end JSON.stringify result

transform = (query-result, transformation, parameters, callback) !-->
    [err, func] = compile-and-execute-livescript "(#transformation\n)", (transformation-context! <<< (require \moment) <<< (require \prelude-ls) <<< parameters)
    return callback err if !!err

    try
        transformed-result = func query-result
    catch err
        return callback err, null

    callback null, transformed-result

<[
    /apis/branches/:branchId/execute
    /apis/queries/:queryId/execute
    /apis/branches/:branchId/queries/:queryId/execute
]> |> each (route) ->
    app.get route, (req, res) ->
        {branch-id, query-id}? = req.params
        {display or \query, cache or false}? = req.parsed-query

        err, {data-source, query, transformation, presentation}? <- do ->
            return (get-query-by-id query-database, query-id) if !!query-id
            get-latest-query-in-branch query-database, branch-id
        return die res, err if !!err

        parameters = {} <<< req.parsed-query

        err, query-result <- execute data-source, query, parameters, cache
        return die res, err if !!err
        return res.end JSON.stringify query-result, null, 4 if display == \query

        err, transformed-result <- transform query-result, transformation, parameters
        return die res, err if !!err
        return res.end JSON.stringify transformed-result, null, 4 if display == \transformation

        res.render \public/presentation/presentation.html, {presentation, transformed-result, parameters}

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
        err, {data-source, query-id, query-title, query, transformation}? <- do ->
            return (get-query-by-id query-database, req.params.query-id) if !!req.params.query-id
            get-latest-query-in-branch query-database, req.params.branch-id

        filename = query-title.replace /\s/g, '_'

        if format in text-formats
            parameters = {} <<< req.parsed-query
                |> obj-to-pairs
                |> reject ([key]) -> key in <[format width height]>
                |> pairs-to-obj

            err, query-result <- execute data-source, query, parameters, false
            return die res, err if !!err

            err, transformed-result <- transform query-result, transformation, parameters
            return die res, err if !!err

            download = (extension, content-type, content) ->
                res.set \Content-disposition, "attachment; filename=#{filename}.#{extension}"
                res.set \Content-type, content-type
                res.end content

            match format
            | \json => download \json, \application/json, JSON.stringify transformed-result, null, 4
            | \text => download \txt, \text/plain, JSON.stringify transformed-result, null, 4

        else

            # use the query-id for naming the file
            image-file = "public/screenshots/#{query-id}.png"
            {create-page, exit} <- phantom.create
            {open, render}:page <- create-page
            page.set \viewportSize, {width, height}
            page.set \onLoadFinished, ->
                <- render image-file
                res.set \Content-disposition, "attachment; filename=#{filename}.png"
                res.set \Content-type, \image/png
                create-read-stream image-file .pipe res
                exit!

            # compose the url for executing the query
            base-url = url-parser req.url .pathname .replace \/export, \/execute
            query-string = req.query
                |> obj-to-pairs
                |> reject ([key]) -> key in <[format width height]>
                |> pairs-to-obj
                |> -> {} <<< it <<< {display: \presentation, cache: \false}
            open "http://127.0.0.1:#{http-port}#{base-url}?#{querystring.stringify query-string}"


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
