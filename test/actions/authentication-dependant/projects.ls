require! \../../../actions
require! \assert
{Promise, bind-p, new-promise, return-p, reject-p} = require \../../../async-ls
{all, filter, keys, map, reject} = require \prelude-ls
require! \../../../exceptions/UnAuthenticatedException
{test-authentication-dependant-action} = (require \../test-utils)!

describe \projects, ->

    describe \insert-project, ->
    
        specify 'unauthenticated user must not be allowed to create a project', ->
            test-authentication-dependant-action undefined, \insertProject, [title: \test], false, (err) -> 
                err instanceof UnAuthenticatedException
            
        specify 'authenticated user must be allowed to create a project', ->
            test-authentication-dependant-action \guest, \insertProject, [title: \test], true
    
    describe \get-projects, ->
    
        # :: [String] -> Map String, a -> Boolean
        has-keys = (ks, obj) -->
            ks |> all (k) -> k in (keys obj)
        
        # :: String -> [String] -> p b
        can-view-props = (ks, user-id) -->
            role = user-id
            test-authentication-dependant-action user-id, \getProjects, [\owner], true, (projects) ->
                (projects.length > 0) and all (has-keys ks), projects
    
        
        public-props = <[permission users ownerId title]>
        private-props = <[connections]>
        all-props = public-props ++ private-props
        
        specify 'owner & admin must be allowed to view all properties of a project', ->
            Promise.map <[owner admin]>, (user-id) -> 
                role = user-id
                result <- bind-p (can-view-props all-props, user-id)
                if result 
                    return-p null 
                else 
                    reject-p "#{role} must be allowed to view #{all-project-props.to-string!}"
                
        specify 'collaborator & guest must not be allowed to view project.connections', ->
            Promise.map <[collaborator guest]>, (user-id) ->
                role = user-id
                result <- bind-p (can-view-props private-props, user-id)
                if result 
                    reject-p "#{role} must not be allowed to view connections property of a project"
                else
                    return-p null
                
        specify 'collaborator must be allowed to view public properties of a project', ->
            result <- bind-p (can-view-props public-props, \collaborator)
            if result 
                return-p null
            else
                reject-p "collaborator must be allowed to view #{public-project-props.to-string!}"