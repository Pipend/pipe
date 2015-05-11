{concat-map, map, unique, sort, find, id, zip-with} = require \prelude-ls
{fill-intervals, trend-line, rextend} = require \./_utils.ls
fill-intervals-f = fill-intervals

module.exports = ({Plottable, plot-chart, d3, nv}) -> new Plottable do
    (view, result, {x, y, y-axis, x-axis, show-legend, show-controls, use-interactive-guideline, clip-edge, fill-intervals, key, values, color}, continuation) !-->

        <- nv.add-graph 

        all-values = result |> concat-map (-> (values it) |> concat-map x) |> unique |> sort

        if fill-intervals is not false
            all-values := all-values |> map (-> [it, 0]) |> (-> fill-intervals-f it, if fill-intervals is true then 0 else fill-intervals) |> map (.0)
        
        result := result |> map (d) ->
            key: key d
            values: all-values |> map ((v) -> [v, (values d) |> find (-> (x it) == v) |> (-> if !!it then (y it) else (fill-intervals))])

        chart = nv.models.stacked-area-chart!
            .x (.0)
            .y (.1)
            .use-interactive-guideline use-interactive-guideline
            .show-controls show-controls
            .clip-edge clip-edge
            .show-legend show-legend


        if !!color
            chart.color color . (.key)

        chart
            ..x-axis.tick-format x-axis.tick-format
            ..y-axis.tick-format y-axis.tick-format
        
        plot-chart view, result, chart

        <- continuation chart, result
        
        chart.update!

    {
        x: (.0)
        y: (.1)
        key: (.key)
        values: (.values)
        show-legend: true
        show-controls: true
        clip-edge: true
        fill-intervals: false
        use-interactive-guideline: true
        y-axis: 
            tick-format: (d3.format ',')
        x-axis: 
            tick-format: (timestamp)-> (d3.time.format \%x) new Date timestamp
    }