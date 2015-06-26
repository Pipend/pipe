# all functions in this file are for use on server-side only (either by server.ls or query-types)

{bindP, from-error-value-callback, new-promise, returnP, to-callback} = require \./async-ls
config = require \./config
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
        if !!err then rej err else res compiled-query-parameters
    else
        res parameters

# execute :: (CancellablePromise cp) => DB -> DataSource -> String -> QueryParameters -> Cache -> String -> cp result
export execute = (query-database, {query-type, timeout}:data-source, query, parameters, cache, op-id) -->

    # return cached-result (if any) otherwise execute the query and cache the result
    compiled-query-parameters <- bindP (compile-parameters query-type, parameters)
    read-from-cache = [
        typeof cache == \boolean and cache === true
        typeof cache == \number and (new Date.value-of! - query-cache[key]?.cached-on) / 1000 < cache
    ] |> any id        
    key = md5 JSON.stringify {data-source, query, compiled-query-parameters}
    return returnP {} <<< query-cache[key] <<< {from-cache: true, execution-duration: 0} if read-from-cache and !!query-cache[key]

    cancellable-promise = add-op do
        op-id
        {
            data-source
            query
            parameters: compiled-query-parameters
        }
        ((require "./query-types/#{query-type}").execute query-database, data-source, query, compiled-query-parameters)
        
    cancel-timer = set-timeout (-> cancellable-promise.cancel!), (timeout ? 90000)
    execution-start-time = Date.now!

    cancellable-promise.then do
        (result) ->
            clear-timeout cancel-timer
            execution-end-time = Date.now!
            query-cache[key] := {
                result
                execution-start-time
                execution-end-time
            }
            returnP {} <<< query-cache[key] <<< {from-cache: false, execution-duration: execution-end-time - execution-start-time}
        (err) -> 
            clear-timeout cancel-timer
            throw err

# transform :: result -> String -> CompiledQueryParameters -> p transformed-result
export transform = (query-result, transformation, parameters) -->
    res, rej <- new-promise 
    [err, func] = compile-and-execute-livescript "(#transformation\n)", (transformation-context! <<< (require \moment) <<< (require \prelude-ls) <<< parameters)
    return rej err if !!err

    try
        res (func query-result)
    catch err
        return rej err

# add-op :: (CancellablePromise cp) => String -> OpInfo -> cp result -> cp result
add-op = (op-id, op-info, cancellable-promise) -->
    ops.push {op-id, op-info, cancellable-promise}
    cancellable-promise

# cancel-op :: String -> Status
export cancel-op = (op-id) ->
    op = ops |> find -> it.op-id == op-id
    return [false, Error "no op with #{op-id} found"] if !op
    return [false, Error "no running op with #{op-id} found"] if !op.cancellable-promise.is-pending!
    op.cancellable-promise.cancel!
    [true, null]

# running-ops :: () -> [String]
export running-ops = ->
    ops
        |> filter (.cancellable-promise.is-pending!)
        |> map ({op-id, op-info}) -> {op-id, op-info}


