# all functions in this file are for use on server-side only (either by server.ls or query-types)

{bindP, from-error-value-callback, new-promise, returnP, to-callback} = require \./async-ls
config = require \./config
transformation-context = require \./public/transformation/context
{readdir-sync} = require \fs
{compile} = require \livescript
md5 = require \MD5
{any, concat-map, difference, each, filter, find, find-index, group-by, id, keys, map, maximum-by, Obj, obj-to-pairs, pairs-to-obj, reject, sort-by, values} = require \prelude-ls
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

# get-all-keys-recursively :: Map k, v -> (k -> v -> Bool) -> [String]
export get-all-keys-recursively = (object, filter-function) -->
    keys object |> concat-map (key) -> 
        return [] if !filter-function key, object[key]
        return [key] ++ (get-all-keys-recursively object[key], filter-function)  if typeof object[key] == \object
        [key]

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

# fill-data-source :: PartialDataSource -> DataSource
export fill-data-source = (partial-data-source) -->
    connection-prime = config?.connections?[partial-data-source?.type]?[partial-data-source?.connection-name]
    data-source = {} <<< (connection-prime or {}) <<< partial-data-source

# compile-parameters :: String -> QueryParameters -> p CompiledQueryParameters
export compile-parameters = (type, parameters) -->
    res, rej <- new-promise
    if \String == typeof! parameters
        [err, compiled-query-parameters] = compile-and-execute-livescript parameters, (require "./query-types/#{type}").get-context!
        if !!err then return rej err else res compiled-query-parameters
    else
        res parameters

# execute :: (CancellablePromise cp) PartialDataSource -> String -> QueryParameters -> Cache -> String -> cp result
export execute = (query-database, partial-data-source, query, parameters, cache, op-id) -->

    # get the complete data-source which includes the query-type
    {type}:data-source <- bindP do ->
        res, rej <- new-promise
        {type}:data-source? = fill-data-source partial-data-source
        return rej new Error "query type: #{type} not found" if typeof (require "./query-types/#{type}") == \undefined
        res data-source

    # return cached-result (if any) otherwise execute the query and cache the result
    compiled-query-parameters <- bindP (compile-parameters type, parameters)
    read-from-cache = [
        typeof cache == \boolean and cache === true
        typeof cache == \number and (new Date.value-of! - query-cache[key]?.time) / 1000 < cache
    ] |> any id        
    key = md5 JSON.stringify {data-source, type, query, compiled-query-parameters}
    return returnP query-cache[key] if read-from-cache and !!query-cache[key]

    cancellable-promise = add-op do
        op-id
        {
            data-source
            query
            parameters: compiled-query-parameters
        }
        ((require "./query-types/#{type}").execute query-database, data-source, query, compiled-query-parameters)
        
    cancel-timer = set-timeout (-> cancellable-promise.cancel!), 90000 #TODO: should come fron config

    cancellable-promise.then do
        (result) ->
            clear-timeout cancel-timer
            query-cache[key] := {result, time: new Date!.value-of!}
            returnP result
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

# add-op :: (CancellablePromise cp) => String -> cp result -> Extras -> cp result
add-op = (op-id, op-info, cancellable-promise) -->
    ops.push {op-id, op-info, cancellable-promise}
    cancellable-promise

# cancel-op :: String -> Void
export cancel-op = (op-id) !->
    ops 
        |> find -> it.op-id == op-id
        |> -> it?.cancellable-promise.cancel!

# running-ops :: () -> [String]
export running-ops = ->
    ops
        |> filter (.cancellable-promise.is-pending!)
        |> map ({op-id, op-info}) -> {op-id, op-info}
































