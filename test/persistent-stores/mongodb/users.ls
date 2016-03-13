require! \assert
{bind-p} = require \../../../async-ls

module.exports = (db-p, store-p) ->

    describe \users, ->
        
        describe \insert-user, ->
        
            specify 'must insert user', ->
                db <- bind-p db-p 
                {insert-user} <- bind-p store-p
                <- bind-p insert-user username: \charlie
                {username} <- bind-p (db.collection \users .find-one username: \charlie)
                assert.equal \charlie, username
    
        describe \get-user-by-email, ->
    
            specify 'must return the user with the specified email address', ->
                db <- bind-p db-p
                {get-user-by-email} <- bind-p store-p
                <- bind-p (db.collection \users .insert-one email: \a@a.com)
                expected-user <- bind-p get-user-by-email \a@a.com
                {_id} <- bind-p (db.collection \users .find-one email: \a@a.com)
                assert.equal expected-user._id, _id.to-hex-string!