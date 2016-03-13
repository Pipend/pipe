require! \assert
{bind-p, new-promise, return-p} = require \../../../async-ls
{ObjectID} = require \mongodb
{map} = require \prelude-ls

module.exports = (db-p, store-p) ->

    describe \projects, ->
        
        describe \insert-project, ->
        
            specify 'must insert project', ->
                db <- bind-p db-p
                {insert-project} <- bind-p store-p
                expected-title = "Project#{Math.floor Math.random! * 1000}"
                {_id} <- bind-p insert-project title: expected-title
                {title} <- bind-p (db.collection \projects .find-one {_id: new ObjectID _id})
                assert.equal expected-title, title, "expected title to be #{expected-title} instead of #{title}"
                
        describe \get-project, ->
            
            specify 'must return the project by id', ->
                db <- bind-p db-p
                {inserted-id} <- bind-p (db.collection \projects .insert-one title: \project1)
                expected-project-id = inserted-id.to-hex-string!
                {get-project} <- bind-p store-p
                {_id, title} <- bind-p (get-project expected-project-id)
                assert.equal _id, expected-project-id
                assert.equal title, \project1
            
            specify 'must not return a deleted project', ->
                db <- bind-p db-p
                {inserted-id} <- bind-p (db.collection \projects .insert-one title: \project1, status: false)
                {get-project} <- bind-p store-p
                project <- bind-p get-project inserted-id.to-hex-string!
                assert.equal undefined, project
        
        describe \get-projects, ->
        
            specify 'must return a list of all the projects that created by a user', ->
                db <- bind-p db-p
                user <- bind-p (db.collection \users .insert-one username: \bot)
                expected-projects = [0 til 10] |> map -> 
                    owner-id: user.inserted-id.to-hex-string!
                    title: "project#{it}"
                {inserted-ids} <- bind-p (db.collection \projects .insert-many expected-projects)
                {get-projects} <- bind-p store-p
                projects <- bind-p (get-projects user.inserted-id.to-hex-string!)
                assert projects.length == expected-projects.length
                
        describe \update-project, ->
            
            specify 'must update project', ->
                db <- bind-p db-p
                {inserted-id} <- bind-p (db.collection \projects .insert-one title: \project1)
                {update-project} <- bind-p store-p
                <- bind-p (update-project inserted-id.to-hex-string!, permission: \private)
                {_id, permission, title} <- bind-p (db.collection \projects .find-one _id: inserted-id)
                assert.equal inserted-id.to-hex-string!, _id
                assert.equal \project1, title
                assert.equal \private, permission
            
        describe \delete-project, ->
            
            specify 'must delete the project', ->
                db <- bind-p db-p
                {delete-project, get-project} <- bind-p store-p
                {inserted-id} <- bind-p (db.collection \projects .insert-one title: \project1)
                <- bind-p delete-project inserted-id.to-hex-string!
                project <- bind-p get-project inserted-id.to-hex-string!
                assert.equal undefined, project