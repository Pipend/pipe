{id, map, filter, drop, Obj, obj-to-pairs, sort-by, zip} = require \prelude-ls

{create-class, create-factory, find-DOM-node}:React = require \react

module.exports = ({{Plottable}:Reactive, d3}) ->


    # private to Reactive.layout module
    Wrapper = create-factory create-class do 

        render: ->
            React.DOM.div ref: \stub

        # cplotter :: Change -> Meta -> View -> IO ()  already knows about the result

        component-did-mount: ->
            @props.cplotter @props.change, @props.meta, (find-DOM-node @refs.stub)
            
        component-did-update: ->
            @props.cplotter @props.change, @props.meta, (find-DOM-node @refs.stub)
            
            


    layout = (direction, cells) -->
        if "Array" != typeof! cells
            cells := drop 1, [].slice.call arguments

        App = create-factory create-class do 
            
            render: -> 
                
                React.DOM.div do
                    style:
                        display: 'flex'
                        flex-direction: direction
                        width: '100%'
                        height: '100%'
                
                    (@props.rx-cells `zip` [0 til cells.length]) |> map ([{cplotter, flex}:rx-cell, index]) ~>
                    
                        React.DOM.div do
                            { 
                                style: 
                                    width: '100%'
                                    height: '100%'
                                    overflow: 'auto'
                                    position: 'relative'
                                    flex: flex
                                key: index
                            }
                            Wrapper { 
                                cplotter
                                meta: @props.meta
                                change: @props.change
                            }
            
        new Reactive.Plottable do 
            (result) ->
                cells |> map ({plottable, size, grow, shrink, basis}) ->
                    {
                        cplotter: plottable._cplotter result
                        flex: if !!basis then "#{grow} #{shrink} #{basis}" else if !!size then "1 1 #{size}" else '1 1 100%'
                    }

            (change, meta, view, rx-cells, {iden}:options, continuation) !-->
                
                React.render do 
                        App {
                            rx-cells
                            meta
                            change
                        }
                        view
                
            {
                iden: id
            }

    {
        layout: layout

        layout-horizontal: layout \row

        layout-vertical: layout \column

    }