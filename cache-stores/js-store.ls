{bindP, returnP} = require \../async-ls
{cache-store} = require \../config
{expires-in}? = cache-store

# p Store
module.exports = do ->

    store = {}

    # remove :: String -> p Boolean
    remove = (key) ->
        delete store[key]
        returnP true

    # save :: String -> object -> p object
    save = (key, object) -->
        store[key] = {object, timestamp: Date.now!}
        returnP object

    # load :: String -> p object
    load = (key) ->
        {object, timestamp}:value? = store[key]

        return returnP null if !value

        if !!expires-in and (Date.now! - timestamp) > (expires-in * 1000)
            <- bindP remove key
            returnP null
        
        else
            returnP object

    returnP {save, load, remove}