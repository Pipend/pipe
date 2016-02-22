Promise = require \bluebird

CancellationError = ((@message) !-> @name = \CancellationError)
    ..prototype = Error.prototype

# with-cancel-and-dispose :: (CancellablePromise cp) => cp a -> (() -> p b) -> (() -> Void) -> cp a
with-cancel-and-dispose = (p, f, g = (->)) ->
    p.then (result) -> 
        g!
        return-p result
    p.catch Promise.CancellationError, (e) ->
        p = f!
            ..finally -> g!
        throw (new CancellationError p)

# bind-p :: (CancellablePromise cp) => cp a -> (a -> cp b) -> cp b
bind-p = (p, f) -> p.then (a) -> f a

# new-promise :: (CancellablePromise cp) => ((x -> Void) -> (Error -> Void) -> Void) -> cp x
new-promise = (callback) -> new Promise ((res, rej) -> callback res, rej) .cancellable!

# return-p :: (CancellablePromise cp) => a -> cp a
return-p = (a) -> new-promise (res) -> res a

# from-error-value-callback :: ((Error, result) -> void, Object?) -> CancellablePromise result
from-error-value-callback = (f, self = null) ->
    (...args) ->
        _res = null
        _rej = null
        args = args ++ [(error, result) ->
            return _rej error if !!error
            _res result
        ]
        (res, rej) <- new-promise
        _res := res
        _rej := rej
        try
            f.apply self, args
        catch ex
            rej ex

# to-callback :: (CancellablePromise cp) => cp x -> CB x -> Void
to-callback = (p, callback) !-->
    p.then ->
        callback null, it
    p.catch (err) ->
        return (callback err, null) if err?.name != \CancellationError
        err, result <- to-callback err?.message
        callback (err or result), null

# sequence-p :: (CancellablePromise cp) => [cp a] -> cp [a]
sequence-p = ([p, ...ps]) ->
    return return-p [] if !p
    a <- bind-p p
    as <- bind-p (sequence-p ps)
    [a] ++ as

module.exports = {with-cancel-and-dispose, bind-p, return-p, from-error-value-callback, to-callback, new-promise, sequence-p}
