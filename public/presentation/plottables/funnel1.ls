{map, id, reverse} = require \prelude-ls

module.exports = ({Plottable, d3}) -> new Plottable do 
    (view, result, {range || [1, 350], size = 50, color = \#fff, column-color, color-range || ["red","blue"], vertical, flip}:options) ->

        domain-max = d3.max result, -> it[1]
        domain-min = d3.min result, -> it[1]
        
        scale = d3.scale.linear!
            .domain [domain-min, domain-max]
            .range range

        ramp = d3.scale.linear!
            .domain [domain-min, domain-max]
            .range color-range

        d3.select view
            ..append \div
            .select-all \div .data (if flip then (result |> reverse) else result)
                ..enter!
                    ..append \div
                        ..append \p
                            ..text ([label])->
                                label
                        ..append \p
                            ..text ([_, num])->
                                num
                        ..attr \style, ([_, num, color])->
                            ([
                                "background: #{color || column-color || ramp(num)}"
                                "text-align: center"
                            ] ++ (
                                if vertical
                                    [
                                        "width: #{scale(num)}px"
                                        "height: #{size}px"
                                        "margin: auto"
                                        "border-bottom: solid 1px white"
                                    ]
                                else
                                    [
                                        "height: #{scale(num)}px"
                                        "width: #{size}px"
                                        "margin: auto 0"
                                        "border-right: solid 1px white"
                                    ]
                            )).join \;
            ..select \div
                ..attr \style, ([] ++ (if !vertical then "display: flex" else [])).join \;
                ..attr \class, \funnel1-container
            ..select-all \p
                ..attr \style, "padding: 0; margin: 0; color: #{color}"