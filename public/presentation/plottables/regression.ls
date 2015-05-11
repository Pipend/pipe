{map, minimum, maximum, pow} = require \prelude-ls

module.exports = ({Plottable, d3}) -> new Plottable do
    (view, result, {margin, x, y, size, y-range, y-axis, x-axis, tooltip}:options, continuation) !->

        least-squares = (x-series, y-series) ->
            reduce-sum-func = (prev, cur) -> prev + cur
            
            x-bar = (x-series.reduce reduce-sum-func) * 1.0 / x-series.length
            y-bar = (y-series.reduce reduce-sum-func) * 1.0 / y-series.length

            ssXX = x-series
                .map (d) -> Math.pow d - x-bar, 2
                .reduce reduce-sum-func
            
            ssYY = y-series
                .map (d) -> Math.pow d - y-bar, 2
                .reduce reduce-sum-func
                
            ssXY = x-series
                .map (d, i) -> (d - x-bar) * (y-series[i] - y-bar)
                .reduce reduce-sum-func
                
            slope = ssXY / ssXX
            intercept = y-bar - (x-bar * slope)
            r-square = (Math.pow ssXY, 2) / (ssXX * ssYY)
            
            [slope, intercept, r-square]

        y-range := {
            min: (map y) >> minimum
            max: (map y) >> maximum
        } <<< y-range

        width = view.client-width - margin.left - margin.right
        height = view.client-height - margin.top - margin.bottom

        x-scale = d3.scale.linear!.range [0, width]
            ..domain [(result |> (map x) >> minimum), (result |> (map x) >> maximum)]
        y-scale = d3.scale.linear!.range [height, 0]
            ..domain [(y-range.min result), (y-range.max result)]
        size-scale = d3.scale.linear!.range [3, 10]
            ..domain [(result |> map size |> minimum), (result |> map size |> maximum)]

        svg = d3.select view .append \div .attr \style, "position: absolute; left: 0px; top: 0px; width: 100%; height: 100%" .append \svg
            .attr \class, \regression
            .attr \width, width + margin.left + margin.right
            .attr \height, height + margin.top + margin.bottom
            .append \g
            .attr \transform, "translate(" + margin.left + "," + margin.top + ")"


        if tooltip is not null
            tip = d3.tip!
                .attr \class, \d3-tip
                .offset [-10, 0]
                .html tooltip

            svg.call tip

        
        svg.append \g .attr \class, 'x axis'


        svg
            .append \g .attr \class, 'y axis'
            .attr \transform, "translate(0, 0)"
            .call do ->
                d3.svg.axis!
                    .scale y-scale
                    .orient \left
                    .tick-format y-axis.tick-format

        svg
            .append \g .attr \class, 'x axis'
            .attr \transform, "translate(0, #{view.client-height - margin.bottom - margin.top})"
            .call do ->
                d3.svg.axis!
                    .scale x-scale
                    .orient \bottom
                    .tick-format x-axis.tick-format


        circle = svg.select-all \circle
            .data result
            .enter!.append \circle
            .attr "cx", x-scale . x
            .attr "cy", y-scale . y
            .attr "r", size-scale . size
            .style "fill", (d) -> "blue"

        if tooltip is not null
            circle
                .on \mouseover, tip.show
                .on \mouseout, tip.hide


        
        least-squares-coeff = leastSquares (map x, result), (map y, result)
        line = -> least-squares-coeff.0 * it + least-squares-coeff.1

        x1 = result |> minimum . (map x)
        y1 = line x1
        x2 = result |> maximum . (map x)
        y2 = line x2
        
        trendline = svg.selectAll \.trendline
            .data [[x1, y1, x2, y2]]
            .enter!
            .append \line
            .attr \class, \trendline
            .attr \x1, (d) -> x-scale d[0]
            .attr \y1, (d) -> y-scale d[1]
            .attr \x2, (d) -> x-scale d[2]
            .attr \y2, (d) -> y-scale d[3]
            .attr \stroke, \black
            .attr \stroke-width, 1

        svg
            ..append \text
            .text "y = #{(d3.format '0.2f') least-squares-coeff.0} x + #{(d3.format '0.2f') least-squares-coeff.1}"
            .attr \class, \text-label
            .attr \x, (d) -> margin.left * 0.6
            .attr \y, (d) -> if y-scale y1 > view.client-height / 2 then margin.bottom * 0.6 else view.client-height - 2.4 * margin.bottom

            ..append \text
            .text "r square = #{(d3.format '0.2f') least-squares-coeff.2}"
            .attr \class, \text-label
            .attr \x, (d) -> margin.left * 0.6
            .attr \y, (d) -> if y-scale y1 > view.client-height / 2 then margin.bottom else view.client-height - 2 * margin.bottom


    {
        x: (.x)
        y: (.y)
        size: (.size)
        y-axis:
            format: (d3.format '0.2f')
            label: 'Y'
        x-axis:
            format: (d3.format '0.2f')
            label: 'X'
        y-range: null 
        tooltip: null
        margin: {top: 20, right:20, bottom: 50, left: 50}
    }