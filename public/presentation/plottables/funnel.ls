require \d3-funnel
{id, map, fold, filter, replicate, zip, empty, reverse, concat-map} = require \prelude-ls

to-closed-shape = (result) ->
    result ++ (reverse <| result |> map ({x, y}) -> {x, y: -y}) ++ [result.0]

module.exports = ({Plottable, d3}) ->
    view, result, {margin, color, name, size} <- new Plottable _, {
        margin: {top: 20, right: 20, bottom: 20, left: 20}
        color:
            (d3.scale.linear!.domain [1, 0.75, 0] .range ['#2c7bb6', '#ffffbf', '#d7191c'] .interpolate d3.interpolateHcl) .
            (.ratio)
        name: (.name)
        size: (.size)
        
    }
    
    
    width = view.client-width - margin.left - margin.right
    height = view.client-height - margin.top - margin.bottom
    
    shapes = result 
        |> fold do
            ([..., latest]:acc, a) ->
                switch
                | empty acc => [a]
                | (latest.size < a.size) => acc # remove missng funnel steps
                | _ => acc ++ [a]
            []
        |> fold do 
            ([...init, latest]:acc, a) ->
                switch
                | empty acc => [[a]]
                | latest.length < 2 => init ++ [latest ++ [a]]
                | _ => acc ++ [[latest.1, a]]
            []
        |> (shapes) -> shapes ++ [replicate 2 shapes[*-1].1] # last shape
        |> (shapes) ->
            (shapes `zip` [1 to shapes.length + 1]) 
            |> map ([data, x]) -> {x, data, name: "#{name data.0}"}
        |> map ({x, data, name}) ->
            name: name
            x: x
            points: to-closed-shape [{x: 0, y: (size data.0)}, {x: 1, y: (size data.1)}]
        |> fold do 
            ([..., latest]:acc, a) ->
                switch 
                | empty acc => [{ratio: 1} <<< a]
                | _ => acc ++ [{ratio: (a.points.0.y / latest.points.0.y)} <<< a]
            []
            
        
    x = d3.scale.linear!.range [0, width] .domain [1, shapes.length + 1]
    gwidth = (x 2) - (x 1)
    
    line = do ->
        xl = d3.scale.linear!.range [0, gwidth] .domain [0, 1]
        yl = d3.scale.linear!.range [height, 0] .domain d3.extent (shapes |> concat-map (.points |> map (.y)))
    
        d3.svg.line!.x (.x |> xl) .y (.y |> yl) .interpolate 'linear'
    

    pformat = d3.format '%'
    nformat = d3.format ',f'
    
    d3.select view .attr \style, "font-size: 12px" .append \svg 
        .attr \width, width + margin.left + margin.right
        .attr \height, height + margin.top + margin.bottom
        .append \g .attr \style, (-> "transform: translate(#{margin.left}px, #{margin.top}px)")
        .select-all \g.shape .data shapes
        .enter!
            ..append \g .attr \class, \shape .attr \style, (-> "transform: translate(#{x it.x}px, 0px)")
                ..append \path 
                        ..attr \d, (.points) >> line
                        ..attr \fill, color
                ..append \g .attr \style, (-> "transform: translate(#{gwidth / 2}px, #{height / 2 + 10}px)")
                    ..append \text
                        ..attr \text-anchor, \middle .attr \dominant-baseline, \central
                        ..attr \dy, \-2em .text (-> it.name)
                    ..append \text
                        ..attr \text-anchor, \middle .attr \dominant-baseline, \central
                        ..attr \dy, \0em .text nformat . (.points.0.y)
                    ..append \text
                        ..attr \text-anchor, \middle .attr \dominant-baseline, \central
                        ..attr \dy, \2em .text pformat . (.ratio)
                #..append \g .attr \style, (-> "transform: translate(#{gwidth / 2}px, #{height - 30}px)")
                    #..append \text
                        #..attr \text-anchor, \middle .attr \dominant-baseline, \central
                        #..attr \dy, \-2em .text (-> it.name)
                    #..append \text
                        #..attr \text-anchor, \middle .attr \dominant-baseline, \central
                        #..attr \dy, \0em .text nformat . (.points.0.y)
                    #..append \text
                        #..attr \text-anchor, \middle .attr \dominant-baseline, \central
                        #..attr \dy, \2em .text pformat . (.ratio)
