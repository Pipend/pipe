moment = require \moment
{Obj, average, concat-map, drop, each, filter, find, foldr1, id, keys, map, maximum, minimum, obj-to-pairs, sort, sum, tail, take, unique, mod, round} = require \prelude-ls

parse-date = (s) -> new Date s
today = -> ((moment!start-of \day .format "YYYY-MM-DDT00:00:00.000") + \Z) |> parse-date
{object-id-from-date, date-from-object-id} = require \../utils.ls


round1 = (n, x) -->
    if n == 0 then Math.round x else (Math.round x * (n = Math.pow 10, n)) / n

find-precision = (n) ->
    f = (p) ->
        if (round1 p, n) == n then 
            p 
        else if p > 15 then 16 else f (p + 1)
    f 0
    
bucketize = (size) ->
    s2 = size / 2
    p = find-precision size
    map (round1 p) . (-> it - it `mod` size) . (+ s2)

fill-intervals-ints = (v, default-value = 0) ->
    x-scale = v |> map (.0)
    fill-range do 
        v
        minimum x-scale
        maximum x-scale
        null
        default-value

fill-range = (v, min-x-scale, max-x-scale, x-step, default-value = 0) ->

    gcd = (a, b) -> match b
        | 0 => a
        | _ => gcd b, (a % b)
    
    x-step = x-step or (v 
        |> map (.0) 
        |> foldr1 gcd)

    [0 to (max-x-scale - min-x-scale) / x-step]
        |> map (i) ->
            x-value = min-x-scale + x-step * i
            [, y-value]? = v |> find ([x])-> x == x-value
            [x-value, y-value or default-value]

fill-intervals = (list, default-value = 0) ->
    precision = Math.pow 10, (list |> map find-precision . (.0) |> maximum)
    list |> map (-> [(round it.0 * precision), it.1]) |> (-> fill-intervals-ints it, default-value) |> map (-> [it.0 / precision, it.1])

# all functions defined here are accessible by the transformation code
module.exports = ->  

    {

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

        # bucketize :: Number -> [Number] -> [Number]
        bucketize

        round1


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
