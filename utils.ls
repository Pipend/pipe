# all functions in this file are for use on server-side only (either by server.ls or query-types)

{bindP, from-error-value-callback, new-promise, returnP, to-callback, with-cancel-and-dispose} = require \./async-ls
config = require \./config
cache-store = require "./cache-stores/#{config.cache-store.type}"
transformation-context = require \./public/transformation/context
{readdir-sync} = require \fs
{compile} = require \livescript
md5 = require \MD5
{any, concat-map, dasherize, difference, each, filter, find, find-index, group-by, id, keys, map, maximum-by, Obj, obj-to-pairs, pairs-to-obj, reject, sort-by, values} = require \prelude-ls
vm = require \vm

query-cache = {}
ops = []

# this method differs from public/utils.ls::compile-and-execute-livescript, 
# it uses the native nodejs vm.run-in-new-context method to execute javascript instead of eval
# compile-and-execute-livescript :: String -> Map k, v -> [err, result]
export compile-and-execute-livescript = (livescript-code, context) -->
    die = (err)-> [err, null]
    try 
        js = compile livescript-code, {bare: true}
    catch err
        return die "livescript transpilation error: #{err.to-string!}"
    try 
        result = vm.run-in-new-context js, context
    catch err
        return die "javascript runtime error: #{err.to-string!}"
    [null, result]

export compile-and-execute-livescript-p = (livescript-code, context) -->
    resolve, reject <- new-promise
    [err, result] = compile-and-execute-livescript livescript-code, context
    return reject err if !!err
    resolve result


# compile-and-execute-javascript :: String -> Map k, v -> [err, result]
export compile-and-execute-javascript = (javascript-code, context) -->
    die = (err)-> [err, null]
    try 
        result = vm.run-in-new-context javascript-code, context
    catch err
        return die "javascript runtime error: #{err.to-string!}"
    [null, result]

export compile-and-execute-javascript-p = (javascript-code, context) -->
    resolve, reject <- new-promise
    [err, result] = compile-and-execute-javascript javascript-code, context
    return reject err if !!err
    resolve result


{get-all-keys-recursively} = require \./public/utils.ls
export get-all-keys-recursively

# DB -> String -> p Query
export get-latest-query-in-branch = (query-database, branch-id) -->
    collection = query-database.collection \queries
    results <- bindP (from-error-value-callback collection.aggregate, collection) do 
        * $match: {branch-id,status: true}
        * $sort: _id: -1
    return returnP results.0 if !!results?.0
    new-promise (, rej) -> rej "unable to find any query in branch: #{branch-id}" 

# DB -> String -> p Query
export get-query-by-id = (query-database, query-id) -->
    collection = query-database.collection \queries
    results <- bindP (from-error-value-callback collection.aggregate, collection) do 
        * $match: 
            query-id: query-id
            status: true
        * $sort: _id: - 1
        * $limit: 1
    return returnP results.0 if !!results?.0
    new-promise (, rej) -> rej "query not found #{query-id}"

# synchronous function, uses promises for encapsulating error
# extract-data-source :: DateSourceCue -> p DataSource
export extract-data-source = (data-source-cue) ->

    # throw error if query-type does not exist
    query-type = require "./query-types/#{data-source-cue?.query-type}"
    if typeof query-type == \undefined
        return new-promie (, rej) -> rej new Error "query type: #{data-source-cue?.query-type} not found"

    # clean-data-source :: UncleanDataSource -> DataSource
    clean-data-source = (unclean-data-source) ->
        unclean-data-source
            |> obj-to-pairs
            |> reject ([key]) -> (dasherize key) in <[connection-kind complete]>
            |> pairs-to-obj

    returnP clean-data-source do 
        match data-source-cue?.connection-kind
            | \connection-string => 
                parsed-connection-string = (query-type?.parse-connection-string data-source-cue.connection-string) or {}
                {} <<< data-source-cue <<< parsed-connection-string
            | \pre-configured =>
                connection-prime = config?.connections?[data-source-cue?.query-type]?[data-source-cue?.connection-name]
                {} <<< data-source-cue <<< (connection-prime or {})
            | _ => {} <<< data-source-cue

# compile-parameters :: String -> QueryParameters -> p CompiledQueryParameters
export compile-parameters = (query-type, parameters) -->
    res, rej <- new-promise
    if \String == typeof! parameters
        [err, compiled-query-parameters] = compile-and-execute-livescript parameters, (require "./query-types/#{query-type}").get-context!
        if !!err then rej err else res (compiled-query-parameters ? {})
    else
        res parameters

# Cache parameter must be Either Boolean Number, if truthy, it indicates we should attempt to read the result from cache before executing the query
# the Cache parameter does not affect the write behaviour, the result will always be saved to the cache store irrespective of this value
# execute :: (CancellablePromise cp) => DB -> DataSource -> String -> QueryParameters -> Cache -> String -> cp result
export execute = (query-database, {query-type, timeout}:data-source, query, transpilation, parameters, cache, op-id) -->

    # get CompiledQueryParameters from QueryParameters
    compiled-query-parameters <- bindP (compile-parameters query-type, parameters)

    # the cache key
    key = md5 JSON.stringify {data-source, query, compiled-query-parameters}

    # connect to the cache store (we need the save function for storing the result in cache later)
    {load, save} <- bindP cache-store
    cached-result <- bindP do -> 

        # avoid loading the document from cache store, if Cache parameter is falsy
        if typeof cache == \boolean and cache === false
            return returnP null

        # load the document from cache store & use the result based on the value of Cache parameter
        cached-result <- bindP load key
        if !!cached-result
            read-from-cache = [
                typeof cache == \boolean and cache === true
                typeof cache == \number and ((Date.now! - cached-result?.execution-end-time) / 1000) < cache
            ] |> any id
            if read-from-cache
                return returnP {} <<< cached-result <<< {from-cache: true, execution-duration: 0}

    return returnP cached-result if !!cached-result

    # look for a running op that matches the document hash    
    main-op = ops |> find -> it.document-hash == key and it.cancellable-promise.is-pending! and it.parent-op-id == null

    # create the main op if it doesn't exist
    main-op = 
        | typeof main-op == \undefined =>
            
            # (CancellablePromise cp) => cp result -> cp ResultWithMeta
            cancellable-promise = do ->
                execution-start-time = Date.now!
                result <- bindP ((require "./query-types/#{query-type}").execute query-database, data-source, query, transpilation, compiled-query-parameters)
                execution-end-time = Date.now!
                saved-result <- bindP save key, {result, execution-start-time, execution-end-time}, Date.now! + (5 * 1000)
                returnP {} <<< saved-result <<< {from-cache: false, execution-duration: execution-end-time - execution-start-time}

            # cancel the promise if execution takes longer than data-source.timeout milliseconds
            cancel-timer = set-timeout (-> cancellable-promise.cancel!), timeout ? 90000
            cancellable-promise.finally -> clear-timeout cancel-timer

            # create op & add it to ops list, in order to cancel it in future
            op = 
                op-id: "main_#{op-id}"
                parent-op-id: null
                document: 
                    data-source: data-source
                    query: query
                    parameters: compiled-query-parameters
                document-hash: key
                cancellable-promise: cancellable-promise
            ops.push op
            op

        | _ => main-op

    # create a child op
    child-op = 
        op-id: op-id
        parent-op-id: main-op.op-id
        cancellable-promise: with-cancel-and-dispose do 
            new-promise (res, rej) -> 
                err, result <- to-callback main-op.cancellable-promise
                if !!err then rej err else res result
            -> returnP \killed-it
    ops.push child-op

    child-op.cancellable-promise


# transform :: result -> String -> CompiledQueryParameters -> p transformed-result
export transform = (query-result, transformation, parameters) -->
    res, rej <- new-promise 
    [err, func] = compile-and-execute-livescript "(#transformation\n)", (transformation-context! <<< (require \moment) <<< (require \prelude-ls) <<< parameters)
    return rej err if !!err

    try
        res (func query-result)
    catch err
        return rej err

# cancel-op :: String -> Status
export cancel-op = (op-id) ->
    op = ops |> find -> it.op-id == op-id
    return [false, Error "no op with #{op-id} found"] if !op
    return [false, Error "no running op with #{op-id} found"] if !op.cancellable-promise.is-pending!

    # cancel the op's promise if this is the main op
    if op.parent-op-id == null
        op.cancellable-promise.cancel!

    else
        sibling-ops = ops |> filter -> it.parent-op-id == op.parent-op-id and it.cancellable-promise.is-pending!

        # cancel the child promise if the child has other live siblings
        if sibling-ops.length > 1
            op.cancellable-promise.cancel!

        # cancel the main promise if this is the only child
        else
            cancel-op op.parent-op-id
            
    [true, null]

# running-ops :: () -> [String]
export running-ops = ->
    ops |> filter (.cancellable-promise.is-pending!)


