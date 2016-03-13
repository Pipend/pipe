require! \./config

# all functions in this file are for use on server-side only (either by server.ls or query-types)
{bind-p, from-error-value-callback, new-promise, return-p, reject-p, to-callback, with-cancel-and-dispose} = require \./async-ls
{EventEmitter} = require \events
md5 = require \MD5

# prelude
{any, concat-map, dasherize, difference, each, filter, find, find-index, group-by, id, 
keys, map, maximum-by, Obj, obj-to-pairs, pairs-to-obj, reject, sort-by, Str, values} = require \prelude-ls

# generate-task-id :: () -> String
generate-task-id = -> "#{Math.floor Math.random! * 1000}"

module.exports = class TaskManager extends EventEmitter

    (@memory-store) -> 
        # task-id, project-id, role of the user that started it
        # Op ::      
        #   project-id :: String
        #   user-id :: String
        #   user-role :: String # used for caching the role of the user-id
        #   task-id :: String
        #   display :: Display (information for displaying a task on client-side)
        #   parent-task-id :: String?
        #   document-hash :: String
        #   cancellable-promise :: cancellable-promise
        #   creation-time :: LongInt
        @tasks = []

    /*
    Cache parameter must be Either Boolean Number, if truthy, it indicates we should attempt to read the result from cache 
    before executing the query, the Cache parameter does not affect the write behaviour, the result will always be saved to 
    the cache store irrespective of this value.
    
    Store1 ::
      get-document-version :: String -> Int -> cp Document 
      get-latest-document :: String -> cp Document
      
    Display ::
    
        how?
        url :: String
        method :: String
        user-agent :: Phantom | Browser
        sub-query :: Boolean (indicates if the task is part of multi-query)
        
        who?
        user-id :: String
        username :: String
        user-role :: owner | admin | collaborator | guest
        
        what?
        project-id :: String
        project-title :: String
        source :: Either {document-id, version}, {data-source-cue, query, transpilation-language}
        document-title :: String
        query-type :: String
    */
    execute: (
        project-id
        {user-id, user-role}
        store1 # :: Store1 (used in multi-query)
        task-id # :: String
        display # :: Display (information for displaying a task on client-side)
        {query-type, timeout}:data-source # {queryType :: (mssql | mysql | ...), host :: String, port :: Int, ...}
        query # :: String (document.query)
        transpilation-language # :: String
        compiled-parameters
        cache # :: Boolean
    ) ->
        
        # throw error if task-id is already present in list
        if ((@task ? []) |> find (task) ->
            task-id == task.task-id and 
            task.cancellable-promise.is-pending!)
            return reject-p new Error "task with #{task-id} already exists"
        
        
        # the cache key
        hash = md5 JSON.stringify {project-id, data-source, query, transpilation-language, compiled-parameters}

        # connect to the cache store (we need the save function for storing the result in cache later)
        cached-result <~ bind-p do ~> 

            # avoid loading the document from cache store, if Cache parameter is falsy
            if typeof cache == \boolean and cache === false
                return return-p null

            # load the document from cache store & use the result based on the value of Cache parameter
            cached-result <~ bind-p @memory-store.load hash
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

            # look for a running task that matches the document hash 
            main-task = @tasks |> find (task) ~> 
                task.project-id == project-id and 
                task.document-hash == hash and 
                task.cancellable-promise.is-pending! and 
                task.parent-task-id == null

            # create the main task if it doesn't exist
            main-task = 
                | typeof main-task == \undefined =>

                    wait-p = (ms) ->
                        res, rej <- new-promise 
                        <- set-timeout _, ms
                        res [{}]

                    # (CancellablePromise cp) => cp result -> cp ResultWithMeta
                    cancellable-promise = do ~>

                        # t0
                        execution-start-time = Date.now!

                        result <~ bind-p do 
                            (require "./query-types/#{query-type}").execute do 
                                (display-override, data-source, query, transpilation-language, compiled-parameters, cache) ~> 
                                    @execute do 
                                        project-id
                                        {user-id, user-role}
                                        store1
                                        generate-task-id!
                                        {} <<< display <<< display-override <<< sub-task: true
                                        data-source
                                        query
                                        transpilation-language
                                        compiled-parameters
                                        cache
                                store1 # used by multi-query for get-document-version & get-latest-document
                                data-source
                                query
                                transpilation-language
                                compiled-parameters
    
                        # t1
                        execution-end-time = Date.now!

                        # cache the result
                        saved-object <- bind-p @memory-store.save do 
                            hash
                            {result, execution-start-time, execution-end-time}

                        {} <<< saved-object <<<
                            from-cache: false
                            execution-duration: execution-end-time - execution-start-time

                    # cancel the promise if execution takes longer than data-source.timeout milliseconds
                    cancel-timer = set-timeout do 
                        -> cancellable-promise.cancel!
                        timeout ? 90000

                    # emit a change event on completion
                    cancellable-promise.finally ~> 
                        clear-timeout cancel-timer
                        @emit \change

                    # create main task
                    task = 
                        task-id: "main_#{task-id}"
                        parent-task-id: null
                        project-id: project-id
                        user-id: user-id
                        user-role: user-role # used for caching the starter's role
                        display: display
                        document-hash: hash
                        cancellable-promise: cancellable-promise 
                        creation-time: Date.now!

                    # add main-task to the list
                    @tasks.push task

                    task

                | _ => main-task

            # create a child task
            {cancellable-promise}:child-task = 
                task-id: task-id
                parent-task-id: main-task.task-id
                project-id: project-id
                user-id: user-id
                user-role: user-role # used for caching the starter's role
                display: display

                # wrap the cancellable promise of the main-task 
                # (this way when the child task is cancelled, it doesn't cancel the main-task)
                cancellable-promise: with-cancel-and-dispose do 
                    new-promise (res, rej) -> 
                        err, result <- to-callback main-task.cancellable-promise
                        if !!err then rej err else res result
                    -> 
                        console.log \2
                        return-p \killed-it
                    ~> @emit \change 

                creation-time: Date.now!

            # add the child-task to the list
            @tasks.push child-task

            # tell everyone that a new task has started
            @emit \change

            # return the cancellable promise (not the task)
            return-p cancellable-promise


    # cancel-task :: String -> p Op
    cancel-task: (project-id, task-id) ->
        task = @tasks |> find -> it.project-id == project-id and it.task-id == task-id
        return reject-p Error "no task with #{task-id} found" if !task
        return reject-p Error "no running task with #{task-id} found" if !task.cancellable-promise.is-pending!

        # cancel the task's promise if this is the main task
        if task.parent-task-id == null
            task.cancellable-promise.cancel!
            return-p task

        else
            sibling-tasks = @tasks |> filter ->
                it.project-id == task.project-id and 
                it.parent-task-id == task.parent-task-id and 
                it.cancellable-promise.is-pending!

            # cancel the child promise if the child has other live siblings
            if sibling-tasks.length > 1
                task.cancellable-promise.cancel!
                return-p task

            # cancel the main promise if this is the only child
            else
                @cancel-task task.project-id, task.parent-task-id

    # running-tasks :: () -> [Op]
    running-tasks: (project-id) ->
        @tasks |> filter (task) -> 
            task.project-id == project-id and task.cancellable-promise.is-pending!
