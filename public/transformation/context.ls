require! \moment

# prelude
{Obj, average, concat-map, drop, each, filter, find, foldr1, gcd, id, keys, map, maximum, 
minimum, obj-to-pairs, sort, sum, tail, take, unique, mod, round} = require \prelude-ls

Rx = require \rx
io = require \socket.io-client
{object-id-from-date, date-from-object-id} = require \../utils.ls

# parse-date :: String -> Date
parse-date = (s) -> new Date s

# today :: a -> Date
today = -> ((moment!start-of \day .format "YYYY-MM-DDT00:00:00.000") + \Z) |> parse-date

# round1 :: Int -> Number 
round1 = (n, x) -->
    if n == 0 then Math.round x else (Math.round x * (n = Math.pow 10, n)) / n

# find-precision :: Number -> Int
find-precision = (n) ->
    f = (p) ->
        if (round1 p, n) == n then 
            p 
        else if p > 15 then 16 else f (p + 1)
    f 0

# bucketize :: Number -> [Number] -> [Int]
bucketize = (size) ->
    s2 = size / 2
    p = find-precision size
    map (round1 p) . (-> it - it `mod` size) . (+ s2)

# (k -> v -> kv) -> Map k v -> [kv]
fold-obj-to-list = (merger, object) -->
  [merger key, value for key, value of object]

# fill-intervals-ints :: [[Number ,Number]] -> Int? [[Number, Number]]
fill-intervals-ints = (list, default-value = 0) ->
    x-scale = list |> map (.0)
    fill-range do 
        list
        minimum x-scale
        maximum x-scale
        null
        default-value

# fill-range :: [[Number, Number]], Number, Number, Number, Number -> [[Number, Number]]
fill-range = (list, min-x-scale, max-x-scale, x-step, default-value = 0) ->
    
    x-step = x-step or (list 
        |> map (.0) 
        |> foldr1 gcd)

    [0 to (max-x-scale - min-x-scale) / x-step] |> map (i) ->
        x-value = min-x-scale + x-step * i
        [, y-value]? = list |> find ([x]) -> x == x-value
        [x-value, y-value ? default-value]

# fill-intervals :: [[Number, Number]], Int? -> [[Number, Number]]
fill-intervals = (list, default-value = 0) ->
    precision = Math.pow 10, (list |> map find-precision . (.0) |> maximum)
    list 
        |> map -> [(round it.0 * precision), it.1] 
        |> -> fill-intervals-ints it, default-value
        |> map -> [it.0 / precision, it.1]

# from-web-socket :: String -> Observer -> Subject
from-web-socket = (address, open-observer) ->
    
    if !!window.socket
        window.socket.close!
        window.socket.destroy!
    
    socket = io do 
        address
        reconnection: true
        force-new: true
    
    window.socket = socket
    
    # Rx.Observable.create :: Observer -> (a -> Void)
    # observable :: Observable
    observable = Rx.Observable.create (observer) ->
        
        if !!open-observer
            socket.on \connect, ->
                open-observer.on-next!
                open-observer.on-completed!
            
        socket.io.on \packet, ({data}?) ->
            if !!data 
                observer.on-next do
                    name: data.0
                    data: data.1
        
        socket.on \error, (err) ->
            observer.on-error err

        socket.on \reconnect_error, (err) ->
            observer.on-error err

        socket.on \reconnect_failed, ->
            observer.on-error new Error 'reconnection failed'

        socket.io.on \close, ->
            observer.on-completed!

        !->
            socket.close!
            socket.destroy!

    observer = Rx.Observer.create (event) ->
        if !!socket.connected
            socket.emit event.name, event.data

    Rx.Subject.create observer, observable

# all functions defined here are accessible by the transformation code
module.exports = -> {

    date-from-object-id

    moment: moment

    day-to-timestamp: -> it * 86400000
    
    fill-intervals

    fill-intervals-ints

    fill-range

    compile-livescript: (require \livescript).compile

    object-id-from-date
    
    parse-date: parse-date

    to-timestamp: (s) -> (moment (new Date s)).unix! * 1000

    today: today!

    transpose: (arr) ->
        keys arr.0
            |> map (column) ->
                arr |> map (row) -> row[column]

    find-precision

    from-web-socket

    bucketize

    round1

    fold-obj-to-list

    # credit: https://gist.github.com/Gozala/1697037
    tco: (fn) ->
        active = null
        next-args = null
        ->
            args = null
            result = null
            next-args := arguments
            if not active
                active := true
                while next-args
                    args := next-args
                    next-args := null
                    result := fn.apply this, args
                active := false
            result

}
