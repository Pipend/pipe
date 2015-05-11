{map, id} = require \prelude-ls
$ = require \jquery-browserify

module.exports = ({Plottable}) -> new Plottable do 
    (view, result, {width, height, background}, continuation) !-->

        heatmap-container = $ view .find \.heatmap-container

        if heatmap-container.size! == 0
            heatmap-container = $ "<div/>" .add-class \heatmap-container
            $ view .append heatmap-container

        heatmap-container .css {width, height, background-image: "url('#{background}')"}

        heatmap-instance = heatmap-container .data \heatmap-instance

        if !heatmap-instance
            heatmap-instance = h337.create {container: heatmap-container.get 0}
            heatmap-container.data \heatmap-instance, heatmap-instance

        heatmap-instance.set-data result

    {
        width: 320
        height: 568
        background: null
    }