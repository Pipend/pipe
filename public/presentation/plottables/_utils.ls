{map, foldr1, maximum, minimum, find, average, any, each, Obj} = require \prelude-ls

export fill-intervals = (v, default-value = 0) ->

    gcd = (a, b) -> match b
        | 0 => a
        | _ => gcd b, (a % b)

    x-scale = v |> map (.0)
    x-step = x-scale |> foldr1 gcd
    max-x-scale = maximum x-scale
    min-x-scale = minimum x-scale
    [0 to (max-x-scale - min-x-scale) / x-step]
        |> map (i)->
            x-value = min-x-scale + x-step * i
            [, y-value]? = v |> find ([x])-> x == x-value
            [x-value, y-value or default-value]


# v :: [[x, y]] -> [[x, <y>]]
export trend-line = (v, sample-size) ->

    [0 to v.length - sample-size]
        |> map (i)->
            new-y = [i til i + sample-size] 
                |> map -> v[it].1
                |> average
            [v[i + sample-size - 1].0, new-y]


# recursively extend a with b
export rextend = (a, b) -->
    btype = typeof! b

    return b if any (== btype), <[Boolean Number String Function]>
    return b if a is null or (\Undefined == typeof! a)

    bkeys = Obj.keys b
    return a if bkeys.length == 0
    bkeys |> each (key) ->
        a[key] = a[key] `rextend` b[key]
    a