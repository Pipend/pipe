{Obj, Str, id, any, average, concat-map, drop, each, filter, find, foldr1, foldl, map, maximum, minimum, obj-to-pairs, pairs-to-obj, sort, sum, tail, take, unique} = require \prelude-ls


unlift = (.raw)
is-highlighted = (.status.highlight ? false)

fmap = (f, o) -->
    switch
    | o?.hasOwnProperty 'status' and o?.hasOwnProperty 'raw' =>
        {raw: (f o.raw), o.status}
    | o instanceof Array =>
        o |> map (fmap f)
    | _ => 
        console.error o
        throw "unsupported fmap input"

# sequence :: m [a] -> [m a]
sequence = ({raw, status}) ->
    raw |> map (r) -> {raw: r, status}

# traverse :: (a -> [b]) -> m a -> [m b]
traverse = (f) -> sequence . (fmap f)


{
    gen-plottable
    plottable
    plot
    with-options
    acompose
    amore
    more
    project
    Plottable: ReactivePlottable
} = (require \./../plottable.ls) fmap


plottables = {
    reactive-table: (require \./reactive-table.ls) {ReactivePlottable, d3, plot, fmap, traverse, unlift, is-highlighted}
    reactive-regression: (require \./reactive-regression.ls) {ReactivePlottable, d3, plot, fmap, traverse, unlift, is-highlighted}
} <<< (require \./reactive-layout.ls) {ReactivePlottable, d3, plot, fmap, unlift, is-highlighted, with-options}

module.exports = ->
    {} <<< plottables <<< {
        ReactivePlottable
        fmap
        is-highlighted
        unlift
    }