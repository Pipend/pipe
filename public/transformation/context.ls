moment = require \moment
{Obj, average, concat-map, drop, each, filter, find, foldr1, id, map, maximum, minimum, obj-to-pairs, sort, sum, tail, take, unique} = require \prelude-ls

parse-date = (s) -> new Date s
today = -> ((moment!start-of \day .format "YYYY-MM-DDT00:00:00.000") + \Z) |> parse-date
{object-id-from-date, date-from-object-id} = require \../utils.ls

# all functions defined here are accessible by the transformation code
module.exports = ->  

    fill-range =(v, min-x-scale, max-x-scale, x-step)->

        gcd = (a, b) -> match b
            | 0 => a
            | _ => gcd b, (a % b)
        
        x-step = x-step or (v 
            |> map (.0) 
            |> foldr1 gcd)

        [0 to (max-x-scale - min-x-scale) / x-step]
            |> map (i)->
                x-value = min-x-scale + x-step * i
                [, y-value]? = v |> find ([x])-> x == x-value
                [x-value, y-value or 0]

    {

        date-from-object-id

        moment: moment

        day-to-timestamp: -> it * 86400000
        
        fill-intervals: (v)->
            x-scale = v |> map (.0)
            fill-range do 
                v
                minimum x-scale
                maximum x-scale

        fill-range

        compile-livescript: (require \LiveScript).compile

        object-id-from-date
        
        parse-date: parse-date

        to-timestamp: (s) -> (moment (new Date s)).unix! * 1000

        today: today!

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
