module.exports = ({Plottable, plot-chart, d3, nv}) -> new Plottable do
    (view, result, {tooltip, show-legend, color, transition-duration, x, y, x-axis, y-axis, margin}, continuation)!->

        <- nv.add-graph

        chart = nv.models.scatter-chart!
            .show-dist-x x-axis.show-dist
            .show-dist-y y-axis.show-dist
            .transition-duration transition-duration
            .color color
            .show-dist-x x-axis.show-dist
            .show-dist-y y-axis.show-dist
            .x x
            .y y
            .margin margin


        chart
            ..scatter.only-circles false

            ..tooltip-content (key, , , {point}) -> 
                tooltip key, point

            ..x-axis.tick-format x-axis.format
            ..y-axis.tick-format y-axis.format

        chart.show-legend show-legend
        plot-chart view, result, chart
        

        <- continuation chart, result
        
        chart.update!

    {
        tooltip: (key, point) -> '<h3>' + key + '</h3>'
        show-legend: true
        transition-duration: 350
        color: d3.scale.category10!.range!
        x-axis:
            format: d3.format '.02f'
            show-dist: true
        x: (.x)

        y-axis:
            format: d3.format '.02f'
            show-dist: true
        y: (.y)
        margin: {top: 30, right: 20, bottom: 50, left: 75}

    }