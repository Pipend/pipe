{map, id} = require \prelude-ls
{fill-intervals} = require \./_utils.ls
fill-intervals-f = fill-intervals

module.exports = ({Plottable, nv, plot-chart}) -> new Plottable do 
    (view, result, {x, y, key, values, y-axis, x-axis, transition-duration, reduce-x-ticks, rotate-labels, show-controls, group-spacing, show-legend, fill-intervals}, continuation) !-->

        <- nv.add-graph

        result := result |> map (r) -> {
            key: (key r)
            values: (values r) |> (map (d) -> [(x d), (y d)]) |> if fill-intervals is not false then (-> fill-intervals-f it, if fill-intervals is true then 0 else fill-intervals) else id
        }


        chart = nv.models.multi-bar-chart!
            .x (.0)
            .y (.1)
            # .transition-duration transition-duration
            .reduce-x-ticks reduce-x-ticks
            .rotate-labels rotate-labels
            .show-controls show-controls
            .group-spacing group-spacing
            .show-legend show-legend
            
        chart 
            ..x-axis.tick-format x-axis.format
            ..y-axis.tick-format y-axis.format

        <- continuation chart, result

        plot-chart view, result, chart
        
    {
        key: (.key)
        values: (.values)
        x: (.0)
        y: (.1)
        y-axis:
            format: id
        x-axis:
            format: id
        transition-duration: 300
        reduce-x-ticks: false # If 'false', every single x-axis tick label will be rendered.
        rotate-labels: 0 # Angle to rotate x-axis labels.
        show-controls: true
        group-spacing: 0.1 # Distance between each group of bars.
        show-legend: true
        fill-intervals: false

    }