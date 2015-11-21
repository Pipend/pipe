{concat-map, map, filter, unique, sort, find, id, zip-with} = require \prelude-ls
{fill-intervals, trend-line, rextend} = require \./../plottables/_utils.ls
fill-intervals-f = fill-intervals


module.exports = ({{Plottable, xplot}:Reactive, d3}) -> new Reactive.Plottable do 
    id
    ({change, toggle, fx, dfx}:change_, meta, view, result, {iden, effects, margin, key, values, x, y, x-scale, y-scale, y-axis, x-axis, color, fill-intervals, tooltip}:options, continuation) !->

        t0 = Date.now!

        width = view.client-width - margin.left - margin.right
        height = view.client-height - margin.top - margin.bottom

        all-values = result |> concat-map (-> (values it) |> concat-map x) |> unique |> sort

        if fill-intervals is not false
            all-values := all-values |> map (-> [it, 0]) |> (-> fill-intervals-f it, if fill-intervals is true then 0 else fill-intervals) |> map (.0)
        
        

        result := result |> map (d) ->
            _iden = iden d
            {
                key: key d
                values: all-values 
                    |> map (v) -> 
                        value = (values d) |> find (-> (x it) == v)
                        x: v
                        y: value |> (-> if false == meta[_iden]?.select then 0 else if !!it then (y it) else (fill-intervals))
                        value: value
                raw: d
                meta: meta[_iden] ? {}
                iden: _iden
            }


        stack = d3.layout.stack!
            .values (.values)
            .x (.x)
            .y (.y)

        x-scale := x-scale.copy!
            .range [0, width]
            .domain (d3.extent (concat-map (.values), result), (.x))
        y-scale := y-scale.copy!
            .range [height, 0]

        area = d3.svg.area!
            .x x-scale . (.x)
            .y0 y-scale . (.y0)
            .y1 y-scale . (-> it.y + it.y0)
            .interpolate options.interpolation


        layers = stack result


        y-scale.domain [0, (d3.max (concat-map (.values), layers), (-> it.y + it.y0))]

        t1 = Date.now!

        x-axis = d3.svg.axis!
            ..scale x-scale
            ..orient 'bottom'
            ..tick-format options.x-axis.format

        y-axis = d3.svg.axis!
            ..scale y-scale
            ..orient 'left'
            ..tickFormat options.y-axis.format


        dview = d3.select view
        svg = dview.select-all 'svg.stacked-area' .data [result]
            ..enter!
                ..append \svg .attr \class, \stacked-area
                    ..append \g .attr \class, \main
                        ..append 'g'
                            ..attr 'class', 'x-axis axis'
                        ..append 'g'
                            ..attr 'class', 'y-axis axis'

            ..attr \width, width + margin.left + margin.right
            ..attr \height, height + margin.top + margin.bottom

            ..select 'g.main'
                ..attr \transform, "translate(" + margin.left + "," + margin.top + ")"

                ..select-all \.layer .data layers
                    ..enter!
                        ..append \path .attr \class, \layer
                            ..on \mouseover, -> fx 'highlight', it.iden
                            ..on \mouseout, -> dfx 'highlight', it.iden
                    ..interrupt!.transition!.duration 1000
                        ..attr \d, -> area it.values
                    ..style \fill, -> 
                        c = color it.key
                        if it.meta.highlight then effects.highlight.color else c

            ..select \.x-axis
                ..attr 'transform', "translate(0, #{height})"
                ..transition! .call x-axis
            ..select \.y-axis
                ..transition!.duration 1000 .call y-axis


        #console.log \d3-render, Date.now! - t1, \compute t1 - t0


    {
        x: (.0)
        y: (.1)
        key: (.key)
        values: (.values)
        x-scale: d3.time.scale!
        y-scale: d3.scale.linear!
        fill-intervals: false
        color: d3.scale.category20!
        effects:
            highlight:
                color: 'yellow'
        x-axis: 
            format: (timestamp) -> (d3.time.format \%x) new Date timestamp
            label: null
            distance: 0
        y-axis:
            format: d3.format ','

        interpolation: 'linear'
        margin: {top: 20, right:20, bottom: 50, left: 50}
    }