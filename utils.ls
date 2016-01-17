# all functions in this file are for use on server-side only (either by server.ls or query-types)
{bind-p, from-error-value-callback, new-promise, return-p, to-callback, with-cancel-and-dispose} = require \./async-ls
require! \./config
cache-store = require "./cache-stores/#{config.cache-store.type}"
{EventEmitter} = require \events
{readdir-sync} = require \fs
md5 = require \MD5

# prelude
{any, concat-map, dasherize, difference, each, filter, find, find-index, group-by, id, 
keys, map, maximum-by, Obj, obj-to-pairs, pairs-to-obj, reject, sort-by, Str, values} = require \prelude-ls

{get-all-keys-recursively} = require \./public/utils.ls
{compile-parameters} = require \pipe-transformation

export get-all-keys-recursively

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

    return-p clean-data-source do 
        match data-source-cue?.connection-kind
            | \connection-string => 
                parsed-connection-string = (query-type?.parse-connection-string data-source-cue.connection-string) or {}
                {} <<< data-source-cue <<< parsed-connection-string
            | \pre-configured =>
                connection-prime = config?.connections?[data-source-cue?.query-type]?[data-source-cue?.connection-name]
                {} <<< data-source-cue <<< (connection-prime or {})
            | _ => {} <<< data-source-cue

# DB -> String -> p Query
export get-latest-query-in-branch = (query-database, branch-id) -->
    collection = query-database.collection \queries
    results <- bind-p (from-error-value-callback collection.aggregate, collection) do 
        * $match: {branch-id,status: true}
        * $sort: _id: -1
    return return-p results.0 if !!results?.0
    new-promise (, rej) -> rej "unable to find any query in branch: #{branch-id}" 

# DB -> String -> p Query
export get-query-by-id = (query-database, query-id) -->
    collection = query-database.collection \queries
    results <- bind-p (from-error-value-callback collection.aggregate, collection) do 
        * $match: 
            query-id: query-id
            status: true
        * $sort: _id: - 1
        * $limit: 1
    return return-p results.0 if !!results?.0
    new-promise (, rej) -> rej "query not found #{query-id}"

class OpsManager extends EventEmitter

    -> @ops = []

    # Cache parameter must be Either Boolean Number, if truthy, it indicates we should attempt to read the result from cache 
    # before executing the query the Cache parameter does not affect the write behaviour, the result will always be saved to 
    # the cache store irrespective of this value
    # execute :: (CancellablePromise cp) => Database -> DataSource -> String -> String -> Parameters -> Boolean -> String -> 
    # OpInfo -> cp result
    execute: (query-database, data-source, query, transpilation-language, compiled-parameters, cache, op-id, op-info) ->

        {query-type, timeout} = data-source

        # the cache key
        key = md5 JSON.stringify {data-source, query, transpilation-language, compiled-parameters}

        # connect to the cache store (we need the save function for storing the result in cache later)
        {load, save} <~ bind-p cache-store
        cached-result <~ bind-p do ~> 

            # avoid loading the document from cache store, if Cache parameter is falsy
            if typeof cache == \boolean and cache === false
                return return-p null

            # load the document from cache store & use the result based on the value of Cache parameter
            cached-result <~ bind-p load key
            if !!cached-result
                read-from-cache = [
                    typeof cache == \boolean and cache === true
                    typeof cache == \number and ((Date.now! - cached-result?.execution-end-time) / 1000) < cache
                ] |> any id
                if read-from-cache
                    return return-p {} <<< cached-result <<< {from-cache: true, execution-duration: 0}

        if !!cached-result
            return-p cached-result

        else

            # look for a running op that matches the document hash 
            main-op = @ops |> find ~> it.document-hash == key and it.cancellable-promise.is-pending! and it.parent-op-id == null

            # create the main op if it doesn't exist
            main-op = 
                | typeof main-op == \undefined =>
                        
                    # (CancellablePromise cp) => cp result -> cp ResultWithMeta
                    cancellable-promise = do ->
                        execution-start-time = Date.now!
                        result <- bind-p do 
                            (require "./query-types/#{query-type}").execute do 
                                query-database
                                data-source
                                query
                                transpilation-language
                                compiled-parameters
                        execution-end-time = Date.now!
                        saved-object <- bind-p save key, {result, execution-start-time, execution-end-time}
                        return-p {} <<< saved-object <<< {
                            from-cache: false
                            execution-duration: execution-end-time - execution-start-time
                        }

                    # cancel the promise if execution takes longer than data-source.timeout milliseconds
                    cancel-timer = set-timeout do 
                        -> cancellable-promise.cancel!
                        timeout ? 90000

                    # emit a change event on completion
                    cancellable-promise.finally ~> 
                        clear-timeout cancel-timer
                        <~ set-timeout _, 100
                        @emit \change

                    # create main op
                    op = 
                        op-id: "main_#{op-id}"
                        op-info: op-info
                        parent-op-id: null
                        document-hash: key
                        cancellable-promise: cancellable-promise
                        creation-time: Date.now!

                    # add main-op to the list
                    @ops.push op

                    op

                | _ => main-op

            # create a child op
            {cancellable-promise}:child-op = 
                op-id: op-id
                op-info: op-info
                parent-op-id: main-op.op-id

                # wrap the cancellable promise of the main-op 
                # (this way when the child op is cancelled, it doesn't cancel the main-op)
                cancellable-promise: with-cancel-and-dispose do 
                    new-promise (res, rej) -> 
                        err, result <- to-callback main-op.cancellable-promise
                        if !!err then rej err else res result
                    -> return-p \killed-it
                    ~>
                        <~ set-timeout _, 100
                        @emit \change 

                creation-time: Date.now!

            # add the child-op to the list
            @ops.push child-op

            # tell everyone that a new op has started
            @emit \change

            # return the cancellable promise (not the op)
            return-p cancellable-promise


    # cancel-op :: String -> [Boolean, Op]
    cancel-op: (op-id) ->
        op = @ops |> find -> it.op-id == op-id
        return [Error "no op with #{op-id} found", null] if !op
        return [Error "no running op with #{op-id} found", null] if !op.cancellable-promise.is-pending!

        # cancel the op's promise if this is the main op
        if op.parent-op-id == null
            op.cancellable-promise.cancel!
            [null, op]

        else
            sibling-ops = @ops |> filter -> it.parent-op-id == op.parent-op-id and it.cancellable-promise.is-pending!

            # cancel the child promise if the child has other live siblings
            if sibling-ops.length > 1
                op.cancellable-promise.cancel!
                [null, op]

            # cancel the main promise if this is the only child
            else
                @cancel-op op.parent-op-id

    # running-ops :: () -> [Op]
    running-ops: ->
        @ops 
            |> filter (.cancellable-promise.is-pending!)
            |> map ({creation-time}:op) -> {} <<< op <<< cpu: Date.now! - creation-time


export ops-manager = new OpsManager!
