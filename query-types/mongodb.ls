config = require \./../config
{compile} = require \LiveScript
{MongoClient, ObjectID, Server} = require \mongodb
{id, concat-map, dasherize, difference, each, filter, find, find-index, foldr1, Obj, keys, map, obj-to-pairs, pairs-to-obj, Str, unique, any, sort-by, floor} = require \prelude-ls
{compile-and-execute-livescript, get-all-keys-recursively} = require \./../utils

poll = {}

# delegate
kill = (db, client, start-time, callback) ->
    return callback new Error "_server-state is not connected", null if 'connected' != db.server-config?._server-state
    
    err, data <- db.collection '$cmd.sys.inprog' .find-one 
    return callback err, null if !!err

    try
        delta = new Date!.value-of! - start-time
        op = data.inprog |> sort-by (-> delta - it.microsecs_running / 1000) |> (.0)

        if !!op
            console.log "cancelling op: #{op.opid}"

            err, data <- db.collection '$cmd.sys.killop' .find-one {op : op.opid}
            return callback err, null if !!err

            db.close!
            client.close!
            callback null, \killed

        else
            callback (new Error "query could not be found #{query}\nStarted at: #{start-time}"), null

    catch error
        callback (new Error "uncaught error"), null

export cancel = (query-id, callback) !-->
    query = poll[query-id]
    return callback (new Error "query not found #{query-id}") if !query
    query.kill callback

export connections = ({connection-name, database}:x, callback) !--> 

    # return the list of all connecitons
    if !connection-name
        return callback do 
            null
            connections: (config?.connections?.mongodb or {}) 
                |> obj-to-pairs
                |> map ([name, value]) -> {label: name, value: name}

    {host, port}:connection? = config?.connections?.mongodb?[connection-name]
    return callback new Error "connection name: #{connection-name} not found in /config.ls" if !connection

    err, result <- switch

        |  !database => (callback) !->

            # return the database in the config, if the connection is a "database-connection"
            return callback null, {connection-name, databases: [connection.database]} if !!connection?.database

            # return the list of all databases, if the connection is a "server-connection"
            err, databases <- execute-mongo-database-query-function do 
                {host, port, database: \admin}
                (db, callback) !-->
                    err, res <- db.admin!.listDatabases
                    callback do 
                        err
                        res.databases |> map (.name)
                {timeout: 5000}
                Math.floor Math.random! * 1000000
            callback err, {connection-name, databases}

        | _ => (callback) !->
            # return the list of all collection for the given connection and database
            err, collections <- execute-mongo-database-query-function do
                {host, port, database: connection?.database or database}
                (db, callback) !-->
                    err, res <- db.collectionNames
                    return callback err, null if !!err
                    callback do 
                        null
                        res |> map ({name}) ->
                            return name if (name.index-of \.) == -1
                            name .split \. .1
                {timeout: 5000}
                Math.floor Math.random! * 1000000
            callback err, {connection-name, database, collections}

    callback err, result

export keywords = (data-source, callback) !-->

    mongo-query = 
        * $sort: _id: -1
        * $limit: 10

    err, results <- execute-mongo-query do 
        data-source
        mongo-query 
        {aggregation-type: \pipeline, timeout: 10000}
        Math.floor Math.random! * 1000000
    return callback err, null if !!err

    collection-keywords = results 
        |> concat-map (-> get-all-keys-recursively it, (k, v)-> typeof v != \function)
        |> unique

    # callback null, do -> 
    #     collection-keywords ++ (collection-keywords |> map -> "$#{it}") ++
    #     config.test-ips ++ 
    #     ((get-all-keys-recursively get-context!, -> true) |> map dasherize) ++
    #     <[$add $add-to-set $all-elements-true $and $any-element-true $avg $cmp $concat $cond $day-of-month $day-of-week $day-of-year $divide 
    #       $eq $first $geo-near $group $gt $gte $hour $if-null $last $let $limit $literal $lt $lte $map $match $max $meta $millisecond $min $minute $mod $month 
    #       $multiply $ne $not $or $out $project $push $redact $second $set-difference $set-equals $set-intersection $set-is-subset $set-union $size $skip $sort 
    #       $strcasecmp $substr $subtract $sum $to-lower $to-upper $unwind $week $year]>

convert-query-to-valid-livescript = (query) ->
    lines = query.split (new RegExp "\\r|\\n")
        |> filter -> 
            line = it.trim!
            !(line.length == 0 or line.0 == \#)
    lines = [0 til lines.length] 
        |> map (i)-> 
            line = lines[i]
            line = (if i > 0 then "},{" else "") + line if line.0 == \$
            line
    "[{#{lines.join '\n'}}]"

#
export get-context = ->
    bucketize = (bucket-size, field) --> $divide: [$subtract: [field, $mod: [field, bucket-size]], bucket-size]
    # {date-from-object-id, object-id-from-date} = require \./../public/scripts/utils.ls
    {} <<< (require \./default-query-context.ls)! <<< {
        
        # dependent on mongo operations
        day-to-timestamp: (field) -> $multiply: [field, 86400000]
        timestamp-to-day: bucketize 86400000
        bucketize: bucketize
        object-id: ObjectID
        # object-id-from-date: ObjectID . object-id-from-date 
        
        # independent of any mongo operations
        # date-from-object-id
    }

execute-mongo-aggregation-pipeline = (collection, query, callback) !-->
    err, result <-  collection.aggregate query, {allow-disk-use: config.allow-disk-use}
    callback err, result

execute-mongo-map-reduce = (collection, query, callback) !-->
    err, result <- collection.map-reduce do
        query.$map
        query.$reduce
        query.$options <<< {finalize: query.$finalize}
    callback err, result

# utility function for executing a single raw mongodb query
# mongo-database-query-function :: (db, callback) --> void;
# can also be used to perform db.****** functions
export execute-mongo-database-query-function = ({host, port, database}, mongo-database-query-function, {timeout}:parameters, query-id, callback) !-->
    
    # connect to mongo server
    server = new Server host, port
    mongo-client = new MongoClient server, {native_parser: true}
    err, mongo-client <- mongo-client.open 
    return callback err, null if !!err

    db = mongo-client.db database

    start-time = new Date!.value-of!

    # store a reference to the query (allowing the user to cancel it later on)
    poll[query-id] =
        kill: (kill-callback) ->
            err, result <- kill db, mongo-client, start-time
            delete poll[query-id]
            kill-callback err, result

    # kill the query on timeout
    set-timeout do
        ->  poll[query-id]?.kill (kill-error, kill-result) -> return console.log \kill-error, kill-error if !!kill-error                
        timeout    

    err, result <- mongo-database-query-function db
    mongo-client.close!
    return callback (new Error "query was killed #{query-id}") if !poll[query-id]
    delete poll[query-id]
    return callback (new Error "mongodb error: #{err.to-string!}"), null if !!err
    callback null, result    

# for executing a single mongodb query from pipe
export execute-mongo-query = ({collection}:data-source, mongo-query, {aggregation-type, timeout}:parameters, query-id, callback) !-->

    f = switch aggregation-type
        | \pipeline => execute-mongo-aggregation-pipeline
        | \map-reduce => execute-mongo-map-reduce
        | _ => (..., callback) -> callback (new Error "Unexpected query aggregation-type '#aggregation-type' \nExpected either 'pipeline' or 'map-reduce'."), null

    err, res <- execute-mongo-database-query-function do 
        data-source
        (db, callback) !--> f (db.collection collection), mongo-query, callback
        {timeout}
        query-id
    return callback err, null if !!err

    if \map-reduce == aggregation-type and !!res.collection-name
        return callback null, {result: {collection-name: res.collection-name, tag: res.db.tag}}

    callback null, res

# for executing a single mongodb query POSTed from client
export execute = (data-source, query, parameters, query-id, callback) !->
    
    query-context = {} <<< get-context! <<< (require \prelude-ls) <<< parameters

    [err, mongo-query] = compile-and-execute-livescript (convert-query-to-valid-livescript query), query-context
    return callback err, null if !!err
    
    # {$map, $reduce, $finalize} are part of one hash
    # convert-query-to-valid-livescript function puts them in a collection: [{$map}, {$reduce}, {$finalize}]
    if '$map' in (mongo-query |> concat-map Obj.keys)
        [err, mongo-query] = compile-and-execute-livescript ("{\n#{query}\n}"), query-context
        return callback err, null if !!err
        aggregation-type = \map-reduce
    
    else
        aggregation-type = \pipeline

    #TODO: get timeout from config
    execute-mongo-query data-source, mongo-query, {aggregation-type, timeout: 1200000}, query-id, callback


