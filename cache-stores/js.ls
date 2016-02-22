{bind-p, return-p} = require \../async-ls
{cache-store} = require \../config

# :: JSStoreConfig -> p CacheStore
module.exports = ({expires-in}?) ->

    store = {}

    # remove :: String -> p Boolean
    remove = (key) ->
        delete store[key]
        return-p true

    # save :: String -> object -> p object
    save = (key, object) -->
        store[key] = {object, timestamp: Date.now!}
        return-p object

    # load :: String -> p object
    load = (key) ->
        {object, timestamp}:value? = store[key]

        return return-p null if !value

        if !!expires-in and (Date.now! - timestamp) > (expires-in * 1000)
            <- bind-p remove key
            return-p null
        
        else
            return-p object

    return-p {save, load, remove}