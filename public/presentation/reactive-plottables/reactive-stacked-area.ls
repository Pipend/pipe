{concat-map, map, unique, sort, find, id, zip-with} = require \prelude-ls
{fill-intervals, trend-line, rextend} = require \./../plottables/_utils.ls
fill-intervals-f = fill-intervals


module.exports = ({ReactivePlottable, plot, d3, unlift, fmap, traverse, por}) -> new ReactivePlottable do 
    (view, lifted, {iden, {is-highlighted, is-selected}:examinors, {fx}:signallers, margin, key, values, x, y, x-scale, y-scale, y-axis, x-axis, fill-intervals, tooltip}:options, continuation) !->

        width = view.client-width - margin.left - margin.right
        height = view.client-height - margin.top - margin.bottom

        result = map unlift, lifted

        all-values = result |> concat-map (-> (values it) |> concat-map x) |> unique |> sort

        if fill-intervals is not false
            all-values := all-values |> map (-> [it, 0]) |> (-> fill-intervals-f it, if fill-intervals is true then 0 else fill-intervals) |> map (.0)
        
        result := lifted |> fmap (d) ->
            key: key d
            values: all-values 
                |> map (v) -> 
                    value = (values d) |> find (-> (x it) == v)
                    x: v
                    y: value |> (-> if !!it then (y it) else (fill-intervals))
                    value: value


        stack = d3.layout.stack!
            .values (.values) . unlift


        x-scale := x-scale.copy!
            .range [0, width]
            .domain (d3.extent (concat-map ((.values) . unlift), result), (.x))
        y-scale := y-scale.copy!
            .range [height, 0]

        area = d3.svg.area!
            .x x-scale . (.x)
            .y0 y-scale . (.y0)
            .y1 y-scale . (-> it.y + it.y0)


        layers = stack result

        color = d3.scale.category20!

        y-scale.domain [0, (d3.max (concat-map ((.values) . unlift), layers), (-> it.y + it.y0))]


        dview = d3.select view
        svg = dview.select-all 'svg.stacked-area' .data [lifted]
            ..enter!
                ..append \svg .attr \class, \stacked-area
                    ..append \g .attr \class, \main

            ..attr \width, width + margin.left + margin.right
            ..attr \height, height + margin.top + margin.bottom

            ..select 'g.main'
                ..attr \transform, "translate(" + margin.left + "," + margin.top + ")"

                ..select-all \.layer .data layers
                    ..enter!
                        ..append \path .attr \class, \layer
                    ..attr \d, -> area (unlift it).values
                    ..style \fill, -> 
                        c = color (unlift it).key
                        if is-highlighted it then 'yellow' else c




    {
        x: (.0)
        y: (.1)
        key: (.key)
        values: (.values)
        x-scale: d3.time.scale!
        y-scale: d3.scale.linear!
        fill-intervals: false

        margin: {top: 20, right:20, bottom: 50, left: 50}
    }