{map, foldr1, maximum, minimum, find, average, any, each, Obj} = require \prelude-ls

{fillIntervals}:t = (require \./../../transformation/context.ls)!

export fill-intervals = fill-intervals

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
    return b if a instanceof Array

    bkeys = Obj.keys b
    return a if bkeys.length == 0
    bkeys |> each (key) ->
        a[key] = (if (Obj.keys a[key]).length > 0 then {} <<< a[key] else a[key]) `rextend` b[key]
    a