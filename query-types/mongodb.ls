{promises:{bindP, from-error-value-callback, new-promise, returnP, to-callback}} = require \async-ls
config = require \./../config
{compile} = require \LiveScript
{MongoClient, ObjectID, Server} = require \mongodb
{id, concat-map, dasherize, difference, each, filter, find, find-index, foldr1, Obj, keys, map, obj-to-pairs, pairs-to-obj, Str, unique, any, sort-by, floor} = require \prelude-ls
{compile-and-execute-livescript, get-all-keys-recursively} = require \./../utils
{date-from-object-id, object-id-from-date} = require \../public/utils

poll = {}

# kill :: (Promise p) => DB -> MongoClient -> StartTime -> p String
kill = (db, client, start-time) ->
    return (new-promise (, rej) -> rej new Error "_server-state is not connected") if 'connected' != db.server-config?._server-state
    
    in-prog-collection = db.collection '$cmd.sys.inprog'
    data <- bindP (from-error-value-callback in-prog-collection.find-one, in-prog-collection)!

    try
        delta = new Date!.value-of! - start-time
        op = data.inprog |> sort-by (-> delta - it.microsecs_running / 1000) |> (.0)

        if !!op
            kill-op-collection = db.collection '$cmd.sys.killop'
            data <- bindP ((from-error-value-callback kill-op-collection.find-one, kill-op-collection) {op : op.opid})
            db.close!
            client.close!
            returnP \killed

        else
            new-promise (, rej) -> rej new Error "query could not be found #{query}\nStarted at: #{start-time}"

    catch error
        new-promise (, rej) -> rej new Error "uncaught error"

# cancel :: (Promise p) => String -> p String
export cancel = (query-id) ->
    query = poll[query-id]
    if !!query then query.kill! else (new-promise (, rej) -> rej new Error "query not found #{query-id}")

# connections :: (Promise p) => a -> p b
export connections = ({connection-name, database}) --> 

    # get-connections :: (Promise p) => a -> p Connections
    get-connections = ->
        res <- new-promise
        res do 
            connections: (config?.connections?.mongodb or {}) 
                |> obj-to-pairs
                |> map ([name, value]) -> {label: (value.label or name), value: name}

    # get-databases :: (Promise p) => String -> p Databases
    get-databases = (connection-name) ->
        {host, port}:connection? = config?.connections?.mongodb?[connection-name]
        return (new-promise (, rej) -> rej new Error "connection name: #{connection-name} not found in /config.ls") if !connection

        # return the database in the config, if the connection is a "database-connection"
        return returnP {connection-name, databases: [connection.database]} if !!connection?.database

        # return the list of all databases, if the connection is a "server-connection"
        databases <- bindP execute-mongo-database-query-function do 
            (db) ->
                admin = db.admin!
                {databases} <- bindP (from-error-value-callback admin.list-databases, admin)!
                returnP (databases |> map (.name))
            {host, port, database: \admin}
            {timeout: 5000}
            "#{Math.floor Math.random! * 1000000}"
        returnP {connection-name, databases}

    # get-collections :: (Promise p) => String -> String -> p Collections
    get-collections = (connection-name, database) -->
        {host, port}:connection? = config?.connections?.mongodb?[connection-name]
        return (new Promise (, rej) -> rej new Error "connection name: #{connection-name} not found in /config.ls") if !connection

        collections <- bindP execute-mongo-database-query-function do
            (db) ->
                results <- bindP (from-error-value-callback db.collection-names, db)!
                returnP do
                    results |> map ({name}) ->
                        return name if (name.index-of \.) == -1
                        name .split \. .1
            {host, port, database: connection?.database or database}
            {timeout: 5000}
            Math.floor Math.random! * 1000000
        returnP {connection-name, database, collections}

    switch
        | !connection-name => get-connections!
        | !database => get-databases connection-name
        | _ => get-collections connection-name, database

# keywords :: (Promise p) => DataSource -> p [String]
export keywords = (data-source) -->
    mongo-query = 
        * $sort: _id: -1
        * $limit: 10

    results <- bindP execute-mongo-query do 
        data-source
        mongo-query 
        {aggregation-type: \pipeline, timeout: 10000}
        Math.floor Math.random! * 1000000

    collection-keywords = results 
        |> concat-map (-> get-all-keys-recursively it, (k, v)-> typeof v != \function)
        |> unique

    returnP do 
        collection-keywords ++ (collection-keywords |> map -> "$#{it}") ++
        ((get-all-keys-recursively get-context!, -> true) |> map dasherize) ++
        <[$add $add-to-set $all-elements-true $and $any-element-true $avg $cmp $concat $cond $day-of-month $day-of-week $day-of-year $divide 
          $eq $first $geo-near $group $gt $gte $hour $if-null $last $let $limit $literal $lt $lte $map $match $max $meta $millisecond $min $minute $mod $month 
          $multiply $ne $not $or $out $project $push $redact $second $set-difference $set-equals $set-intersection $set-is-subset $set-union $size $skip $sort 
          $strcasecmp $substr $subtract $sum $to-lower $to-upper $unwind $week $year]>

# convert-query-to-valid-livescript :: String -> String
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

# get-context :: a -> Context
export get-context = ->
    bucketize = (bucket-size, field) --> $divide: [$subtract: [field, $mod: [field, bucket-size]], bucket-size]
    # {date-from-object-id, object-id-from-date} = require \./../public/scripts/utils.ls
    {} <<< (require \./default-query-context.ls)! <<< {
        
        # dependent on mongo operations
        day-to-timestamp: (field) -> $multiply: [field, 86400000]
        timestamp-to-day: bucketize 86400000
        bucketize: bucketize
        object-id: ObjectID
        object-id-from-date: ObjectID . object-id-from-date 
        
        # independent of any mongo operations
        date-from-object-id
    }

# execute-mongo-aggregation-pipeline :: (Promise p) => MongoDBCollection -> AggregateQuery -> p result
execute-mongo-aggregation-pipeline = (collection, query) --> (from-error-value-callback collection.aggregate, collection) query, {allow-disk-use: config.allow-disk-use}

# execute-mongo-map-reduce :: (Promise p) => MongoDBCollection -> AggregateQuery -> p result
execute-mongo-map-reduce = (collection, {$map, $reduce, $options, $finalize}:query) -->
    (from-error-value-callback collection.map-reduce, collection) do 
        $map
        $reduce
        {} <<< $options <<< {finalize: $finalize}

# utility function for executing a single raw mongodb query
# mongo-database-query-function :: (db, callback) --> void;
# can also be used to perform db.****** functions
# execute-mongo-database-query-function :: (Promise p) => (MongoDatabase -> p result) -> DataSource -> MongoDatabaseQueryParameters -> String -> p result
export execute-mongo-database-query-function = (mongo-database-query-function, {host, port, database}, {timeout}:parameters, query-id) -->
    # connect to mongo server
    server = new Server host, port
    mongo-client = new MongoClient server, {native_parser: true}
    mongo-client <- bindP (from-error-value-callback mongo-client.open, mongo-client)!
    db = mongo-client.db database
    start-time = new Date!.value-of!

    # store a reference to the query (allowing the user to cancel it later on)
    poll[query-id] =

        # a -> p String
        kill: ->
            result <- bindP (kill db, mongo-client, start-time)
            delete poll[query-id]
            returnP result

    # kill the query on timeout
    set-timeout do
        ->  
            return if !poll?[query-id]?.kill
            err <- to-callback poll[query-id].kill!
            console.log \kill-error, err if !!err
        timeout    

    # on execution of the query remove it from the list of running queries
    result <- bindP (mongo-database-query-function db)
    mongo-client.close!
    return (new-promise (, rej) -> rej new Error "query was killed #{query-id}") if !poll[query-id]
    delete poll[query-id]
    returnP result

# for executing a single mongodb query from pipe
# execute-mongo-query :: (Promise p) => DataSource -> AggregateQuery -> MongoQueryParameters -> String -> p result
export execute-mongo-query = ({collection}:data-source, mongo-query, {aggregation-type, timeout}:parameters, query-id) -->

    # select the mongo-query-execution function based on aggregation type
    f = switch aggregation-type
        | \pipeline => execute-mongo-aggregation-pipeline
        | \map-reduce => execute-mongo-map-reduce
        | _ => -> new-promise (, rej) -> rej new Error "Unexpected query aggregation-type '#aggregation-type' \nExpected either 'pipeline' or 'map-reduce'."

    # execute the query & reformat the result for map-reduce queries
    result <- bindP execute-mongo-database-query-function do 
        (db) -> f (db.collection collection), mongo-query
        data-source
        {timeout}
        query-id
    if \map-reduce == aggregation-type and !!result.collection-name
        return returnP {result: {collection-name: result.collection-name, tag: result.db.tag}}
    returnP result

# for executing a single mongodb query POSTed from client
# execute :: (Promise p) => DataSource -> String -> CompiledQueryParameters -> String -> p result
export execute = (data-source, query, parameters, query-id) -->
    {aggregation-type, mongo-query} <- bindP do ->
        res, rej <- new-promise
        
        query-context = {} <<< get-context! <<< (require \prelude-ls) <<< parameters

        [err, mongo-query] = compile-and-execute-livescript (convert-query-to-valid-livescript query), query-context
        return rej err if !!err
        aggregation-type = \pipeline
        
        # {$map, $reduce, $finalize} must be part of one hash in order to perform map-reduce
        # convert-query-to-valid-livescript function puts them in a collection: [{$map}, {$reduce}, {$finalize}]
        if '$map' in (mongo-query |> concat-map Obj.keys)
            [err, mongo-query] = compile-and-execute-livescript ("{\n#{query}\n}"), query-context
            return rej err if !!err
            aggregation-type = \map-reduce
        
        res {aggregation-type, mongo-query}

    #TODO: get timeout from config
    execute-mongo-query data-source, mongo-query, {aggregation-type, timeout: 1200000}, query-id

# default-document :: a -> Document
export default-document = -> 
    {
        query: """
        $sort: _id: -1 
        $limit: 20
        """
        transformation: "id"
        presentation: "json"
        parameters: ""
    }
