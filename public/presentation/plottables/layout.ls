{map, id, filter, Obj, pairs-to-obj, sum, each, take, drop} = require \prelude-ls

module.exports = ({Plottable, d3, plot-chart, nv, plot}) ->

    layout = (direction, cells) --> 
        if "Array" != typeof! cells
            cells := drop 1, [].slice.call arguments

        new Plottable (view, result, options, continuation) !-->
            child-view-sizes = cells |> map ({size, plotter}) ->
                    child-view = document.create-element \div
                        ..style <<< {                            
                            overflow: \auto
                            position: \absolute   
                        }
                        ..class-name = direction
                    view.append-child child-view
                    {size, child-view, plotter, result}

            sizes = child-view-sizes 
                |> map (.size)
                |> filter (size) -> !!size and typeof! size == \Number

            default-size = (1 - (sum sizes)) / (child-view-sizes.length - sizes.length)

            child-view-sizes = child-view-sizes |> map ({child-view, size, plotter, result})-> {child-view, size: (size or default-size), plotter, result}
                
            [0 til child-view-sizes.length]
                |> each (i)->
                    {child-view, size, plotter, result} = child-view-sizes[i]                    
                    position = take i, child-view-sizes
                        |> map ({size})-> size
                        |> sum
                    child-view.style <<< {
                        left: if direction == \horizontal then "#{position * 100}%" else "0%"
                        top: if direction == \horizontal then "0%" else "#{position * 100}%"
                        width: if direction == \horizontal then "#{size * 100}%" else "100%"
                        height: if direction == \horizontal then "100%" else "#{size * 100}%"
                    }
                    plot plotter, child-view, result



    # wraps a Plottable in a cell (used in layout)
    cell: (plotter) -> {plotter}

    # wraps a Plottable in cell that has a size (used in layout)
    scell: (size, plotter) --> {size, plotter}

    layout-horizontal: layout \horizontal

    layout-vertical: layout \vertical