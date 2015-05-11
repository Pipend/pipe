{each, map, id, unique} = require \prelude-ls
$ = require \jquery-browserify

module.exports = ({Plottable, nv, plot-chart}) -> new Plottable do 
    (view, result, {x, y, key, values, x-axis}:options, continuation) !-->

        <- nv.add-graph

        result := result |> map (item) -> 
            {} <<< item <<< {
                key: (key item)
                values: (values item)
                    |> map ->
                        {
                            x: x it
                            y: y it
                        }
            }

        chart = nv.models.multi-chart!
            ..x-axis.tick-format x-axis.format
            ..margin {top: 30, right: 60, bottom: 50, left: 70}

        result 
            |> map (.y-axis)
            |> unique
            |> each ->
                chart["yAxis#{it}"].tick-format options["yAxis#{it}"].format


        plot-chart view, result, chart
        
        if (typeof options?.y-axis1?.show) == \boolean
            $ view .find \div .toggle-class \hide-y1, !options.y-axis1.show

        if (typeof options?.y-axis2?.show) == \boolean
            $ view .find \div .toggle-class \hide-y2, !options.y-axis2.show

        #chart.update!

    {
        key: (.key)
        values: (.values)
        x: (.0)
        y: (.1)
        y-axis1:
            format: id
            show: true
        y-axis2:
            format: id
            show: false
        x-axis:
            format: id        
    }