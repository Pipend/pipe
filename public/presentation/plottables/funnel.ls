require \d3-funnel
{id, map} = require \prelude-ls

module.exports = ({Plottable, nv, plot-chart}) -> new Plottable do 
    (view, result, {scale, label, text}:options, continuation) !-->
        # d3-funnel constructor takes a selector instead of element!
        if !view.id
            view.set-attribute \id, "funnel-#{Date.now!}"

        # apply the scale function to a copy of the result
        scaled-result = result.slice! |> map -> 
            copy = it.slice!
                ..1 = scale copy.1
            copy

        if !!text
            label.text = (i) -> text result[i], scaled-result[i]

        funnel = new D3Funnel '#' + view.id
            ..draw do 
                scaled-result
                options
    
    {
        width: 350,
        height: 400,
        bottomWidth: 1/3,
        bottomPinch: 0,
        isCurved: false,
        curveHeight: 20,
        fillType: \solid,
        isInverted: false,
        hoverEffects: false,
        dynamicArea: false,
        minHeight: false,
        animation: false,
        scale: id
        label:
            fontSize: \14px
            fill: \#fff
        text: ([label, value]) -> "#{label}: #{value}"
        onItemClick: ((d, i) -> )
    }