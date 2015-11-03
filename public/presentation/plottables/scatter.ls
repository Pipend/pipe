{each} = require \prelude-ls
module.exports = ({Plottable, plot-chart, d3, nv}) -> new Plottable do
    (view, result, {tooltip, show-legend, color, transition-duration, x, y, x-axis, y-axis, margin}, continuation) !-->

        <- nv.add-graph

        chart = nv.models.scatter-chart!
            .show-dist-x x-axis.show-dist
            .show-dist-y y-axis.show-dist
            # .transition-duration transition-duration
            .color color
            .show-dist-x x-axis.show-dist
            .show-dist-y y-axis.show-dist
            .x x
            .y y
            .margin margin


        chart
            # ..scatter.only-circles false

            # TODO: nvd3 tooltip is not working
            # ..tooltip (key, , , {point}) -> 
            #     tooltip key, point

            ..x-axis.tick-format x-axis.format
            ..y-axis.tick-format y-axis.format
            ..show-legend show-legend

        [
            [x-axis.label, (.x-axis.axis-label)]
            [x-axis.distance, (.x-axis.axis-label-distance)]
            [y-axis.label, (.y-axis.axis-label)]
            [y-axis.distance, (.y-axis.axis-label-distance)]
        ] |> each ([prop, f]) ->
            if prop is not  null
                (f chart) prop
        


        <- continuation chart, result

        plot-chart view, result, chart

        chart.update!

    {
        tooltip: (key, point) -> '<h3>' + key + '</h3>'
        show-legend: true
        transition-duration: 350
        color: d3.scale.category10!.range!
        x-axis:
            format: d3.format '.02f'
            show-dist: true
            label: null
            distance: null
        x: (.x)

        y-axis:
            format: d3.format '.02f'
            show-dist: true
            label: null
            distance: null
        y: (.y)
        margin: {top: 30, right: 20, bottom: 50, left: 75}

    }