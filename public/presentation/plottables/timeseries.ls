{map, filter, id, concat-map} = require \prelude-ls
{fill-intervals, trend-line, rextend} = require \./_utils.ls
fill-intervals-f = fill-intervals
trend-line-f = trend-line

module.exports = ({Plottable, d3, plot-chart, nv}) -> new Plottable do
    (view, raw-result, {x-label, x, y, x-axis, y-axis, key, values, fill-intervals, trend-line}:options, continuation) !-->

        <- nv.add-graph

        result = raw-result |> map -> {
            key: (key it)
            values: (values it) 
                |> map (-> [(x it), (y it)]) 
                |> if fill-intervals is not false then (-> fill-intervals-f it, if fill-intervals is true then 0 else fill-intervals) else id
        }

        if "Function" == typeof! trend-line
            result := result ++ do -> result |> (map ({key}:me) -> {trend: trend-line key} <<< me) |> filter (.trend is not null) |> map ({key, values, trend}) ->
                {name, sample-size, color} = {
                    name: "#key trend"
                    sample-size: 2
                    color: \red
                } `rextend` trend

                key: name
                color: color
                values: trend-line-f values, sample-size

        chart = nv.models.line-chart!.x (.0) .y (.1)
            ..x-axis.tick-format x-axis.format
            ..y-axis.tick-format y-axis.format

        <- continuation chart, result

        plot-chart view, result, chart

        chart.update!

    {
        fill-intervals: false
        trend-line: null
        # trend-line: (key) ->
        #     name: "#key trend"
        #     sample-size: 0
        #     color: \red
        key: (.key)
        values: (.values)

        x: (.0)
        x-axis: 
            format: (timestamp) -> (d3.time.format \%x) new Date timestamp
            label: 'time'

        y: (.1)
        y-axis:
            format: id
            label: 'Y'

    }