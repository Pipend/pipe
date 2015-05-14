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

# maybe used for parsing parameters in the future
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

die = (res, err) ->
    console.log "DEAD BECAUSE OF ERROR: #{err.to-string!}"
    res.status 500 .end err.to-string!

<[
    \/ 
    \/branches 
    \/branches/:branchId/queries/:queryId
]> |> each (route) ->
    app.get route, (req, res) -> res.render \public/index.html

app.get \/apis/defaultDocument, (req, res) ->
    {type} = config.default-data-source
    res.end JSON.stringify {} <<< query-types[type].default-document! <<< {data-source: config.default-data-source, query-title: 'Untitled query'}

app.get \/apis/queries, (req, res) ->
    err, results <- query-database.collection \queries .aggregate do 
        * $limit: (req.parsed-query?.limit) or 100
        * $sort: _id: (req.parsed-query?.sort-order or 1)
    return die res, err if !!err
    res.end JSON.stringify results, null, 4

get-query-by-id = (query-database, query-id, callback) -->
    err, results <- query-database.collection \queries .aggregate do 
        * $match: {query-id}
        * $sort: _id: - 1
        * $limit: 1
    return callback err, null if !!err
    return callback null, results.0 if !!results?.0
    callback "query not found #{query-id}", null

app.get \/apis/queries/:queryId, (req, res) ->
    err, document <- get-query-by-id query-database, req.params.query-id
    return die res, err if !!err
    res.end JSON.stringify document

execute = (data-source, query, parameters, cache, callback) !-->
    connection-prime = config?.connections?[data-source?.type][data-source?.connection-name]

    {type}? = data-source = {} <<< (connection-prime or {}) <<< data-source
    return callback new Error "query type: #{type} not found" if typeof query-types[type] == \undefined

    {execute, get-context} = query-types[type]

    # parameters is String if coming from the single query interface; 
    # it is an empty object if coming from multi query interface
    if \String == typeof! parameters
        [err, parameters] = compile-and-execute-livescript parameters, get-context!
        return callback err, null if !!err

    # return cached result if any
    key = md5 JSON.stringify {data-source, type, query, parameters}

    read-from-cache = [
        typeof cache == \boolean and cache === true
        typeof cache == \number and (new Date.value-of! - query-cache[key]?.time) / 1000 < cache
    ] |> any id
    return callback null, query-cache[key].result if !!query-cache[key] and read-from-cache

    error, result <- execute data-source, query, parameters, cache
    return callback error if !!error
    
    callback do 
        null
        query-cache[key] = {result, time: new Date!.value-of!}

app.post \/apis/execute, (req, res) ->
    {document:{data-source, query, parameters}}? = req.body
    err, {result}? <- execute data-source, query, parameters, false
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

get-latest-query-in-branch = (query-database, branch-id, callback) -->
    err, results <- query-database.collection \queries .aggregate do 
        * $match: {branch-id,status: true}
        * $sort: _id: -1
    return callback err, null if !!err
    return callback "unable to find any query in branch: #{branch-id}" if (typeof results == \undefined) or results.length == 0
    callback null, results.0

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
    err, result <- query-types[req.params.query-type].connections req.query
    return die res, err if !!err

    res.end JSON.stringify result

app.post \/apis/queryTypes/:queryType/keywords, (req, res) ->
    err, result <- query-types[req.params.query-type].keywords {} <<< req.body <<< (config?.connections?[req.body.type]?[req.body.connection-name] or {})
    return die res, err if !!err

    res.end JSON.stringify result

app.listen http-port
console.log "listening for connections on port: #{http-port}"
