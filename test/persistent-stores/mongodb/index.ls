{Promise, bind-p} = require \../../../async-ls
require! \../../../config
{MongoClient} = require \mongodb
store-p = (require \../../../persistent-stores/mongodb) do
    connection-string: config.testing.persistent-store.mongodb.connection-string
    connection-options: config.testing.persistent-store.mongodb.connection-options
{each} = require \prelude-ls

describe \mongodb, ->

    db-p = MongoClient.connect do 
        config.testing.persistent-store.mongodb.connection-string
        config.testing.persistent-store.mongodb.connection-options
    
    # clean :: p database -> p a
    clean = (db-p) ->
        db <- bind-p db-p
        Promise.map do
            <[users projects documents]>
            -> db.collection it .remove {}

    before-each -> clean db-p
    after-each -> clean db-p
    
    <[users projects documents]> |> each (filename) ->
        (require "./#{filename}") db-p, store-p