redis = require \redis
{bindP, from-error-value-callback, new-promise, returnP} = require \../async-ls
{cache-store} = require \../config
{host, port, database, expires-in}? = cache-store

# :: DataSource -> p Store
module.exports = do ->
    res, rej <- new-promise
    redis-client = redis.create-client port, host, {}
        ..on \connect, ->
            err <- redis-client.select database
            return rej err if !!err

            res do 

                # store :: String -> object -> p object
                save: (key, object) -->
                    <- bindP (from-error-value-callback redis-client.set, redis-client) key, (JSON.stringify object)
                    <- bindP (from-error-value-callback redis-client.expire, redis-client) key, expires-in
                    returnP object

                # load :: String -> object -> p object
                load: (key) ->
                    result <- bindP (from-error-value-callback redis-client.get, redis-client) key
                    returnP JSON.parse result

                # remove :: String -> p Boolean
                remove: (key) ->
                    (from-error-value-callback redis-client.del, redis-client) key

        ..on \error, rej


