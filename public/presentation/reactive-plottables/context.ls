{Obj, Str, id, any, average, concat-map, drop, each, filter, find, foldr1, foldl, map, maximum, minimum, obj-to-pairs, pairs-to-obj, sort, sum, tail, take, unique} = require \prelude-ls


unlift = (.raw)

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

por = (f, g, m) -->
    (f m) || (g m)

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

exports_ = {
    ReactivePlottable, d3, plot, fmap, traverse, unlift, por
}

plottables = {
    reactive-table: (require \./reactive-table.ls) exports_
    reactive-regression: (require \./reactive-regression.ls) exports_
    reactive-stacked-area: (require \./reactive-stacked-area.ls) exports_
} <<< (require \./reactive-layout.ls) {ReactivePlottable, d3, plot, fmap, unlift, por, with-options}

module.exports = ->
    {} <<< plottables <<< {
        ReactivePlottable
        fmap
        unlift
        por
    }