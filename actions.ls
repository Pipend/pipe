{bind-p, new-promise, return-p, reject-p} = require \./async-ls
{all, id, filter, find, map, obj-to-pairs, pairs-to-obj, reject} = require \prelude-ls
{is-equal-to-object} = require \prelude-extension
require! \./exceptions/UnAuthenticatedException
require! \./exceptions/UnAuthorizedException
{compile-and-execute} = require \transpilation

/* 
# Types
UserId :: String
Role :: String
DataSourceId :: String
DataSource :: {
    query-type :: String
    database :: String
    collection :: String
    host :: String
    port :: Int
    user :: String
    password :: String
}
ProjectPermission :: private | publicReadable | publicExecutable | publicReadableAndExecutable
Project :: {
    _id :: String,
    title :: String,
    owner-id :: String,
    users :: Map UserId, Role
    connections :: Map QueryType, (Map ConnectionName, ConnectionDetails)
    permission :: ProjectPermission
}
*/

# Utility
# reject-keys :: ([String, a] -> Bool) -> Map k, v -> Map k, v
reject-keys = (f, o) -->
    o 
    |> obj-to-pairs
    |> reject f
    |> pairs-to-obj

admin-view-of-project = id

collaborator-view-of-project = (project) ->
    admin-view-of-project project
        |> reject-keys (.0 in <[connections]>)

guest-view-of-project = (project) ->
    collaborator-view-of-project project
        |> reject-keys (.0 in <[connections]>)
        
guest-view-of-document = (document) -> document

# Find the role of the given @user-id@ in the @project@
# Role :: guest | owner | admin | collaborator
# get-role :: Project -> String -> Role
get-role = (project, user-id) -->
    return \owner # TODO: removed auth
    switch
    | project.owner-id == user-id => \owner
    | _ => project.users?[user-id] ? \guest

module.exports = (store, task-manager) ->
    
    # actions that never depend on user-id or project-id
    public-actions: -> 
        return-p do
            
            ## --------------- USERS ---------------
            # :: User' -> p User
            insert-user: store.insert-user
            
            # :: String -> p User
            get-user-by-email: store.get-user-by-email
        
            get-user-by-oauth-id: store.get-user-by-oauth-id
        
    # actions that depend on user-id but never depend and project-id
    authentication-dependant-actions: (user-id) ->
        return-p do
            
            ## --------------- PROJECTS ---------------
            # insert-project :: Project' -> p Project
            insert-project: (project) ->
                if !!user-id
                    store.insert-project {} <<< project <<< owner-id: user-id
                else
                    reject-p new UnAuthenticatedException!
            
            # /api/users/:userId/projects
            # :: String -> p [Project]
            get-projects: (owner-id) ->
                projects <- bind-p store.get-projects owner-id
                (projects ? []) 
                    |> map (project) ->
                        # this makes it authentication dependant
                        role = get-role project, user-id
                        switch
                        | role == 'owner' => project
                        | role == 'admin' => admin-view-of-project project
                        | role == 'collaborator' => collaborator-view-of-project project
                        | project.permission in ['publicReadable', 'publicReadableAndExecutable'] => 
                            guest-view-of-project project
                        | _ => undefined
                    |> reject -> typeof it == \undefined
                    |> return-p
                    
        
    # actions that always depend on user-id and project-id
    # :: String, String -> p {}:API
    # each field in the API is a function that takes 0 or some arguments and return a promise
    authorization-dependant-actions: (user-id, project-id) ->

        project <- bind-p store.get-project project-id
        role = get-role project, user-id
        
        # Utility
        # authenticated-user-in-role :: [Role] -> (-> p a) -> p a
        authenticated-user-in-role = (permitted-roles, f) -->
            return f! #TODO: removed auth
            if !user-id
                reject-p new UnAuthenticatedException!
            else
                if role in permitted-roles then f! else reject-p new UnAuthorizedException!
                    
        # Utility
        # public-readable :: (-> p a) -> p a
        public-readable = (f) ->
            [permitted, exception] = switch
            | role in <[owner admin collaborator]> => [true, null]
            | project.permission in ['publicReadable', 'publicReadableAndExecutable'] => [true, null]
            | !user-id and !(project.permission in ['publicReadable', 'publicReadableAndExecutable']) => [false, UnAuthenticatedException]
            | _ => [false, UnAuthorizedException]
            
            [permitted, exception] = [true, null] #TODO: removed authentication

            if permitted then f! else reject-p new exception!
            
        # :: String -> Int -> p Document
        get-document-version = (document-id, version) -->
            public-readable do
                -> store.get-document-version document-id, version
        
        # :: String -> p Document
        get-latest-document = (document-id) ->
            public-readable do
                -> store.get-latest-document document-id
        
        # Utility
        # synchronous function, uses promises for encapsulating error
        # extract this method up (execute1 needs it)
        # :: DataSourceCue -> p DataSource
        extract-data-source = (data-source-cue) ->
            
            # throw error if query-type does not exist
            query-type = require "./query-types/#{data-source-cue?.query-type}"
            if typeof query-type == \undefined
                return new-promie (, rej) -> rej new Error "query type: #{data-source-cue?.query-type} not found"
            
            # clean-data-source :: UncleanDataSource -> DataSource
            clean-data-source = reject-keys (.0 in <[connectionKind complete]>)

            return-p clean-data-source do 
                match data-source-cue?.connection-kind
                    | \connection-string => 
                        parsed-connection-string = (query-type?.parse-connection-string data-source-cue.connection-string) or {}
                        {} <<< data-source-cue <<< parsed-connection-string
                    | \pre-configured =>
                        connection-prime = project.connections?[data-source-cue?.query-type]?[data-source-cue?.connection-name]
                        {} <<< data-source-cue <<< (connection-prime or {})
                    | _ => {} <<< data-source-cue
            
        return-p do
            
            # --------------- PROJECTS ---------------
            # :: -> p Project            
            get-project: ->
                switch
                | role == 'owner' => return-p project
                | role == 'admin' => return-p (admin-view-of-project project)
                | role == 'collaborator' => return-p (collaborator-view-of-project project)
                | role == 'guest' and project.permission == 'publicExecutable' =>
                    reject-p new UnAuthenticatedException!
                | project.permission in <[publicReadable publicReadableAndExecutable]> => 
                    return-p (guest-view-of-project project)
                | _ => reject-p new UnAuthorizedException!
            
            # :: Project' -> p Project
            update-project: (patch) ->
                switch role
                | \owner => store.update-project project._id, patch
                | \admin =>
                    keys-changed = patch
                        |> obj-to-pairs
                        |> reject ([key, value]) -> value `is-equal-to-object` project[key]
                        |> map (.0)
                    allowed-to-change = <[users permission connections]>
                    switch
                    | keys-changed.length == 0 => return-p project
                    | all (-> it in allowed-to-change), keys-changed  => store.update-project project-id, patch
                    | _ => reject-p new UnAuthorizedException!
                | _ => reject-p new UnAuthorizedException!
                
            # :: -> p a
            delete-project: ->
                authenticated-user-in-role do
                    <[owner]>
                    -> store.delete-project project-id
            
            # --------------- DOCUMENTS ---------------
            # :: Document :: p a
            save-document: (document) ->
                authenticated-user-in-role do
                    <[owner admin collaborator]>
                    -> store.save-document {} <<< document <<< {project-id}
                    
            # :: String -> Int -> p Document
            get-document-version: get-document-version
            
            # :: String -> p Document
            get-latest-document: get-latest-document
    
            # :: String -> p [Document]
            get-document-history: (document-id) ->
                public-readable do
                    -> store.get-document-history document-id
    
            # :: p [Document]
            get-documents-in-a-project: ->
                public-readable do
                    -> store.get-documents-in-a-project project-id
                    
            # :: String -> Int -> p a
            delete-document-version: (document-id, version) ->
                authenticated-user-in-role do
                    <[admin collaborator owner]>
                    -> store.delete-document-version document-id, version
            
            # :: String -> p a
            delete-document-and-history: (document-id) ->
                authenticated-user-in-role do
                    <[admin collaborator owner]>
                    -> store.delete-document-and-history document-id
        
            # --------------- EXECUTION ---------------
            execute: (
                task-id # :: String
                display # :: Display
                
                # document-id & version are used for security purposes 
                # to prevent guest user from executing changes to existing documents
                document-id # :: String
                version # :: Int
                
                data-source-cue # :: {queryType :: String, connectionKind :: String, connectionName :: String, ...}
                query # :: String
                transpilation-language # :: String
                compiled-parameters # :: object
                cache # :: Boolean
            ) -->

                # DRY
                task-manager-execute = (data-source, query, transpilation-language, compiled-parameters) ->
                    task-manager.execute do
                        project-id
                        {user-id, user-role: role}
                        {get-document-version, get-latest-document}
                        task-id
                        {} <<< display <<< {
                            user-id: user-id
                            # username: user.username
                            user-role: role
                            project-id: project-id
                            project-title: project.title
                            document-id
                            version
                            data-source-cue
                            query
                            transpilation-language
                            query-type: data-source-cue.query-type
                        }
                        data-source
                        query
                        transpilation-language
                        compiled-parameters
                        cache
                
                if role in <[owner admin collaborator]>
                    data-source <- bind-p (extract-data-source data-source-cue)
                    task-manager-execute data-source, query, transpilation-language, compiled-parameters
                  
                else
                    
                    # guests can only execute the original, unmodified document
                    original-document <- bind-p (store.get-document-version document-id, version)

                    if original-document

                        # guests cannot execute against private dataSource
                        data-source <- bind-p (extract-data-source original-document.data-source-cue)

                        if true or ((project.permission in <[publicExecutable publicReadableAndExecutable]>) and 
                           (data-source.permission == \publicExecutable)) #TODO: removed authentication
                            {query, transpilation, parameters} = original-document
                            compiled-parameters <- bind-p (compile-and-execute parameters, transpilation.query)
                            task-manager-execute data-source, query, transpilation.query, compiled-parameters

                        else

                            # a guest executing a modified private document 
                            reject-p new UnAuthorizedException!
                            
                    else
                        
                        # a guest executing a non-existant document 
                        reject-p new UnAuthorizedException!

            # :: -> p [Op]
            # everybody can see its own runing ops
            # admin collaborator owner can list any running ops
            running-tasks: ->
                task-manager.running-tasks project-id
                    |> filter (task) ->
                        switch
                        | task.user-id == user-id => true
                        | role in <[admin collaborator owner]> => true
                    |> return-p
            
            # :: String -> p String
            # everybody can cancel its own running ops
            # collaborator can also cancel guests ops
            # admin can also cancel other admins and collaborators ops
            # owner can cancel everybody's ops
            cancel-task: (task-id) ->
                task = (task-manager.running-tasks project-id)
                    |> find (.task-id == task-id)
                
                if task and 
                   ((task.user-id == user-id) or
                   (role == 'collaborator' and task.user-role in <[guest]>) or
                   (role == 'admin' and task.user-role in <[guest collaborator admin]>) or
                   (role == 'owner'))
                    task-manager.cancel-task project-id, task-id
                    
                else
                    reject-p 'task not found'
                
            # --------------- DATASOURCES ---------------
            # :: String -> object -> p a
            get-connections: (query-type, obj) -->
                authenticated-user-in-role do
                    <[admin collaborator owner]>
                    -> (require "./query-types/#{query-type}").connections project, obj
           
            # synchronous function, uses promises for encapsulating error
            # extract this method up (execute1 needs it)
            # :: DataSourceCue -> p DataSource
            extract-data-source: extract-data-source