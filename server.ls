body-parser = require \body-parser
{http-port, mongo-connection-opitons, query-database-connection-string}:config = require \./config
express = require \express
{readdir} = require \fs
md5 = require \MD5
{MongoClient} = require \mongodb
{any, each, id, map, obj-to-pairs, pairs-to-obj, reject} = require \prelude-ls
{compile-and-execute-livescript} = require \./utils

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

<[\/ \/branches/:branchId/queries/:queryId]> |> each (route) ->
    app.get route, (req, res) -> res.render \public/index.html

app.get \/apis/queries, (req, res) ->
    err, results <- query-database.collection \queries .aggregate do 
        * $limit: (req.parsed-query?.limit) or 100
        * $sort: _id: (req.parsed-query?.sort-order or 1)
    return die res, err if !!err
    res.end JSON.stringify results, null, 4

get-query-by-id = (query-database, query-id, callback) ->
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

execute = (query-database, {query, parameters}:document, cache, callback) !-->
    connection-prime = config?.connections?[document?.data-source?.type][document?.data-source?.connection-name]

    {type}? = data-source = {} <<< (connection-prime or {}) <<< document.data-source
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
    err, {result}? <- execute query-database, req.body.document, false
    return die res, err if !!err

    res.end JSON.stringify result

app.get \/apis/queries/:queryId/execute, (req, res) ->
    err, document <- get-query-by-id query-database, req.params.query-id
    return die res, err if !!err

    err, {result}? <- execute query-database, document, (req?.parsed-query?.cache or false)
    return die res, err if !!err

    res.end JSON.stringify result

app.get \/apis/queryTypes/:queryType/connections, (req, res) ->
    err, result <- query-types[req.params.query-type].connections req.query
    return die res, err if !!err

    res.end JSON.stringify result

app.listen http-port
console.log "listening for connections on port: #{http-port}"
