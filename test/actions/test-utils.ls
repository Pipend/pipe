require! \../../actions
require! \assert
{Promise, bind-p, new-promise, return-p} = require \../../async-ls
{camelize, each, find, map, Obj, obj-to-pairs, pairs-to-obj} = require \prelude-ls
require! \proxyquire
require! \../../exceptions/UnAuthenticatedException
require! \../../exceptions/UnAuthorizedException

module.exports = (store-replica-extension, task-manager-replica-extension) ->

    proxyquire \../../query-types/mongodb, connections: ->
        connections = 
            *   mongodb: 
                    local: 
                        host: \localhost
            ...

    projects = <[private publicReadable publicExecutable publicReadableAndExecutable]> |> map (permission) ->
        _id: permission
        owner-id: \owner
        title: permission
        permission: permission
        users: 
            admin: \admin
            collaborator: \collaborator
        connections: 
            mongodb:
                local:
                    host: \127.0.0.1
                    port: 27017
                    permission: \publicExecutable
                secret:
                    host: \127.0.0.1
                    port: 27017
                    permission: \private

    # is-type-p :: a -> String -> p b
    is-type-p = (value, expected-type) ->
        res, rej <- new-promise
        if (typeof value) == expected-type 
            res null
        else
            rej "expected #{value} to be of type #{expected-type} instead of #{typeof value}" 

    # ensure that the action invokes the store methods with the correct type
    store-replica = 
        
        ## ---------- users ----------
        insert-user: ({username, email}) ->
            <- bind-p (is-type-p username, \string)
            is-type-p email, \string
        
        get-user-by-email: (email) ->
            is-type-p email, \string
        
        ## ----------- projects ----------- 
        insert-project: ({owner-id}) ->
            is-type-p owner-id, \string
            
        get-project: (project-id) ->
            <- bind-p (is-type-p project-id, \string)
            return-p do 
                projects |> find (._id == project-id)
            
        get-projects: (owner-id) ->
            <- bind-p (is-type-p owner-id, \string)
            return-p projects
        
        update-project: (project-id, patch) ->
            is-type-p patch, \object
        
        delete-project: (project-id) ->
            is-type-p project-id, \string
        
        ## ----------- documents ----------- 
        save-document: (document) ->
            is-type-p document, \object
            
        get-documents-in-a-project: (project-id) ->
            is-type-p project-id, \string
            
        get-document-version: (document-id, version) ->
            <- bind-p (is-type-p document-id, \string)
            is-type-p version, \number
            
        get-latest-document: (document-id) ->
            is-type-p document-id, \string
            
        get-document-history: (document-id) ->
            is-type-p document-id, \string
            
        delete-document-version: (document-id, version) ->
            <- bind-p (is-type-p document-id, \string)
            is-type-p version, \number
        
        delete-document-and-history: (document-id) ->
            is-type-p document-id, \string

    extended-store-replica = store-replica
        |> obj-to-pairs
        |> map ([key, value]) ->
            extended-value = ->
                args = arguments
                result <- bind-p (value.apply null, args)
                if store-replica-extension?[key]
                    store-replica-extension[key].apply null, args
                else
                    return-p result
            [key, extended-value]
        |> pairs-to-obj

    ## ------------- ops -------------
    class TaskManager

        execute: (
            store1 # :: Store1 (used in multi-query)
            {project-id, user-id, user-role}
            data-source # {queryType :: (mssql | mysql | ...), host :: String, port :: Int, username :: String ...}
            query # :: String (document.query)
            transpilation-language # :: String
            compiled-parameters
            cache # :: Boolean
            task-id # :: String
            task-info # :: {url :: String, document :: Document}
        ) ->
            return-p null

        cancel-task: (project-id, task-id) -> 
            return-p ''

        running-tasks: (project-id) ->
            return-p []

    task-manager-replica = new TaskManager!

    ## ------------- actions -------------
    {
        public-actions
        authentication-dependant-actions
        authorization-dependant-actions
    } = actions extended-store-replica, task-manager-replica

    ## ------------- test helpers -------------
    run-promise = (p, must-succeed, post-process = (->)) ->
        if must-succeed
            p.then post-process
        else
            p
            .then -> throw ""
            .catch post-process

    run-action = (actions, action-name, parameters, must-succeed, post-process) ->
        run-promise (actions[action-name].apply null, parameters), must-succeed, post-process
            
    test-public-action = (action-name, parameters, must-succeed, post-process) ->
        actions <- bind-p public-actions!
        run-action actions, action-name, parameters, must-succeed, post-process

    test-authentication-dependant-action = (user-id, action-name, parameters, must-succeed, post-process) ->
        actions <- bind-p authentication-dependant-actions user-id
        run-action actions, action-name, parameters, must-succeed, post-process

    test-authorization-dependant-action = (user-id, project-id, action-name, parameters, must-succeed, post-process) ->
        actions <- bind-p (authorization-dependant-actions user-id, project-id)
        run-action actions, action-name, parameters, must-succeed, post-process

    test-public-readable = (action-name, parameters, on-success = (->)) ->
        <[owner admin collaborator]> |> each (role) ->
            user-id = role
            specify "must run for #{role}", ->
                Promise.map <[private publicReadable publicExecutable publicReadableAndExecutable]>, (project-id) -> 
                    test-authorization-dependant-action do 
                        user-id
                        project-id
                        action-name
                        parameters
                        true
                        on-success
                
        specify "must run for guest in a public project", ->
            Promise.map <[publicReadable publicReadableAndExecutable]>, (project-id) ->
                Promise.map [undefined, \guest], (user-id) ->
                    test-authorization-dependant-action do 
                        user-id
                        project-id
                        action-name
                        parameters
                        true
                        on-success
            
        specify "must not run for guest in a private project", ->
            Promise.map [undefined, \guest], (user-id) ->
                test-authorization-dependant-action do 
                    user-id
                    \private
                    action-name
                    parameters
                    false
                    (err) -> 
                        assert err instanceof UnAuthorizedException, err.to-string!

    test-authenticated-user-in-role = (roles, action-name, parameters, on-success = (->)) ->
        <[owner admin collaborator]> |> each (role) ->
            user-id = role
            must-run = role in roles
            specify "must #{if must-run then 'run' else 'not run'} for #{role}", ->
                Promise.map <[private, publicReadable, publicExecutable, publicReadableAndExecutable]>, (project-id) ->
                    if must-run
                        test-authorization-dependant-action do 
                            user-id
                            \private
                            action-name
                            parameters
                            true
                            on-success
                    else
                        test-authorization-dependant-action do 
                            user-id
                            \private
                            action-name
                            parameters
                            false
                            (err) -> 
                                assert err instanceof UnAuthorizedException, err.to-string!
                    
        specify "must not run for unauthenticated user", ->
            Promise.map <[private publicReadable publicExecutable publicReadableAndExecutable]>, (project-id) ->
                test-authorization-dependant-action do 
                    undefined
                    project-id
                    action-name
                    parameters
                    false
                    (err) -> 
                        assert err instanceof UnAuthenticatedException, err.to-string!

    {
        test-public-action
        test-authentication-dependant-action
        test-authorization-dependant-action
        test-public-readable
        test-authenticated-user-in-role
    }