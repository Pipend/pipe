redis = require \redis
{bind-p, from-error-value-callback, new-promise, return-p} = require \../async-ls

# :: RedisStoreConfig -> p CacheStore
module.exports = ({host, port, database, expires-in}?) ->
    res, rej <- new-promise
    redis-client = redis.create-client port, host, {}
        ..on \connect, ->
            err <- redis-client.select database
            return rej err if !!err

            res do 

                # store :: String -> object -> p object
                save: (key, object) -->
                    <- bind-p (from-error-value-callback redis-client.set, redis-client) key, (JSON.stringify object)
                    <- bind-p (from-error-value-callback redis-client.expire, redis-client) key, expires-in
                    return-p object

                # load :: String -> object -> p object
                load: (key) ->
                    result <- bind-p (from-error-value-callback redis-client.get, redis-client) key
                    return-p JSON.parse result

                # remove :: String -> p Boolean
                remove: (key) ->
                    (from-error-value-callback redis-client.del, redis-client) key

        ..on \error, rej


