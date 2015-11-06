{map, minimum, maximum, pow} = require \prelude-ls

module.exports = ({ReactivePlottable, plot, d3, unlift, fmap, traverse, por}) -> new ReactivePlottable do 
    (view, lifted, {iden, {is-highlighted, is-selected}:examinors, {fx}:signallers, margin, x, y, size, y-range, y-axis, x-axis, tooltip}:options, continuation) !->

        result = map unlift, lifted

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

        
        dview = d3.select view
        svg = dview.select-all 'svg.regression' .data [lifted]
        svg-enter = svg.enter!.append \div .attr \class, \regression .attr \style, "position: absolute; left: 0px; top: 0px; width: 100%; height: 100%" .append \svg
            .attr \class, \regression
            .append \g .attr \class, \main

        dview.select 'svg.regression'
            .attr \width, width + margin.left + margin.right
            .attr \height, height + margin.top + margin.bottom

        svg = dview.select 'g.main'
            .attr \transform, "translate(" + margin.left + "," + margin.top + ")"

        if tooltip is not null
            tip = d3.tip!
                .attr \class, \d3-tip
                .offset [-10, 0]
                .html tooltip

            svg-enter.call tip

        
        svg-enter.append \g .attr \class, 'x axis'


        svg-enter
            .append \g .attr \class, 'y axis'
        svg.select \g.y.axis 
            .attr \transform, "translate(0, 0)"
            .call do ->
                d3.svg.axis!
                    .scale y-scale
                    .orient \left
                    .tick-format y-axis.format

        svg-enter
            .append \g .attr \class, 'x axis'
        svg.select \g.x.axis
            .attr \transform, "translate(0, #{view.client-height - margin.bottom - margin.top})"
            .call do ->
                d3.svg.axis!
                    .scale x-scale
                    .orient \bottom
                    .tick-format x-axis.format


        circle = svg.select-all \circle
            .data lifted
                ..enter!
                    ..append \circle
                        ..on \mouseover, fx 'highlight'
                        ..on \mouseout, fx 'dehighlight'
                ..attr "cx", x-scale . x . unlift
                ..attr "cy", y-scale . y . unlift
                ..attr "r", size-scale . size . unlift
                ..style "fill", (lifted-item) -> 
                    if (is-highlighted `por` is-selected) lifted-item then 'red' else 'blue'

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
        
        trendline = svg.select-all \.trendline .data [[x1, y1, x2, y2]]
            ..enter!
                ..append \line 
                .attr \class, \trendline
            ..attr \x1, (d) -> x-scale d[0]
            ..attr \y1, (d) -> y-scale d[1]
            ..attr \x2, (d) -> x-scale d[2]
            ..attr \y2, (d) -> y-scale d[3]
            ..attr \stroke, \black
            ..attr \stroke-width, 1

        svg-enter
            ..append \text
            .attr \class, 'text-label y'
        svg.select \.text-label.y
            .text "y = #{(d3.format '0.2f') least-squares-coeff.0} x + #{(d3.format '0.2f') least-squares-coeff.1}"
            .attr \x, (d) -> margin.left * 0.6
            .attr \y, (d) -> if y-scale y1 > view.client-height / 2 then margin.bottom * 0.6 else view.client-height - 2.4 * margin.bottom

        svg-enter
            ..append \text
            .attr \class, 'text-label r'
        svg.select \.text-label.r
            .text "r square = #{(d3.format '0.2f') least-squares-coeff.2}"
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
        y-range: null  # {min :: [a] -> Number, max :: [a] -> Number} where `a` is an element in the `result`
        tooltip: null
        margin: {top: 20, right:20, bottom: 50, left: 50}
    }