{map, id} = require \prelude-ls

module.exports = ({Plottable, d3, plot-chart, nv}) -> new Plottable do
    (view, result, {x, y, key, values, maps, stacked, y-axis, margin, show-values, tooltips, tooltip, transition-duration, show-controls}, continuation) !-->
        <- nv.add-graph

        result := result |> map (ds) ->
            key: key ds
            values: (values ds) |> map -> 
                label: x it
                value: (y it) |> maps[key ds]?.0 ? id

        chart = nv.models.multi-bar-horizontal-chart!
            .x (.label)
            .y (.value)
            .margin margin
            .show-values show-values
            .tooltips tooltips
            .tooltip tooltip
            .transition-duration transition-duration
            .show-controls show-controls
            .stacked stacked
        
        chart
            ..y-axis.tick-format y-axis.format

        <- continuation chart, result

        plot-chart view, result, chart

        chart.update!

    {
        x: (.0)
        y: (.1)
        stacked: true
        y-axis:
            format: d3.format ',.2f'
        margin: top: 30, right: 20, bottom: 50, left: 175
        show-values: true
        tooltips: true
        tooltip: (key, x, y, e, graph) ->
            '<h3>' + key + ' - ' + x + '</h3>' +
            '<p>' +  y + '</p>'
        transition-duration: 350
        show-controls: true
        key: (.key)
        values: (.values)
        maps: {}
    }