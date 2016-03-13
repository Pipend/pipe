require! \../../../actions
require! \assert
{bind-p, new-promise, return-p} = require \../../../async-ls
{is-equal-to-object} = require \prelude-extension
require! \../../../exceptions/UnAuthenticatedException
require! \../../../exceptions/UnAuthorizedException
{test-authorization-dependant-action, test-authenticated-user-in-role}:x = (require \../test-utils)!

describe \projects, ->

    describe \get-project, ->

        specify 'owner of a project must be able to view all the properties of a project', ->
            test-authorization-dependant-action do 
                \owner
                \private
                \getProject
                []
                true
                (project) ->
                    assert \object == (typeof project.connections)
                
        specify 'guest role must not be allowed to view a private project', ->
            test-authorization-dependant-action do 
                \guest
                \private
                \getProject
                []
                false
                (err) ->
                    assert err instanceof UnAuthorizedException, err.to-string!
            
        specify 'guest role must have a restricted view of a publicReadable project', ->
            test-authorization-dependant-action do 
                \guest
                \publicReadable
                \getProject
                []
                true
                (project) ->
                    assert \undefined == (typeof project.connections)
    
    describe \update-project, ->
        
        specify 'owner of a project must be able to update any property of a project', ->
            patch =
                users: 
                    alice : \admin
                permission: \private
                connections:
                    mongodb:
                        local:
                            host: \127.0.0.1
                            port: 27017
            test-authorization-dependant-action do
                \owner
                \private
                \updateProject
                [{patch}]
                true
        
        specify 'admin must be allowed to update the users & connections properties of a project', ->
            test-authorization-dependant-action do
                \admin
                \private
                \updateProject
                [{
                    users: 
                        trudy: \admin
                    connections: {}
                }]
                true
                
        specify 'admin must not be allowed to update the ownerId, status & title properties of a project', ->
            test-authorization-dependant-action do
                \admin
                \private
                \updateProject
                [{
                    owner-id: \trudy
                    title: \hacked
                    status: false
                }]
                false
                (err) ->
                    assert err instanceof UnAuthorizedException, err.to-string!
        
        specify 'guest users must not be allowed to update a project', ->
            test-authorization-dependant-action do
                \guest
                \private
                \updateProject
                [{ title: \hacked }]
                false
                (err) ->
                    assert err instanceof UnAuthorizedException, err.to-string!
    
    describe \delete-project, ->
        test-authenticated-user-in-role <[owner]>, \deleteProject, [\private]