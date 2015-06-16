Promise = require \bluebird

CancellationError = ((@message) !-> @name = \CancellationError)
    ..prototype = Error.prototype

# with-cancel :: (CancellablePromise cp) => cp a -> (() -> p b) -> cp a
with-cancel = (p, f) ->
    p.cancellable!
    p.catch Promise.CancellationError, (e) -> 
        throw (new CancellationError f!)

# bindP :: (CancellablePromise cp) => cp a -> (a -> cp b) -> cp b
bindP = (p, f) -> p.then (a) -> f a

# new-promise :: (CancellablePromise cp) => ((x -> Void) -> (Error -> Void) -> Void) -> cp x
new-promise = (callback) -> new Promise ((res, rej) -> callback res, rej) .cancellable!

# returnP :: (CancellablePromise cp) => a -> cp a
returnP = (a) -> new-promise (res) -> res a

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
        err, result <- err?.message.then
        callback (err or result), null

# sequenceP :: (CancellablePromise cp) => [cp a] -> cp [a]
sequenceP = ([p, ...ps]) ->
    return returnP p if !p
    a <- bindP p
    as <- bindP (sequenceP ps)
    [a] ++ as

module.exports = {with-cancel, bindP, returnP, from-error-value-callback, to-callback, new-promise, sequenceP}
