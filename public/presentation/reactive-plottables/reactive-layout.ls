{id, map, filter, drop, Obj, obj-to-pairs, sort-by, zip} = require \prelude-ls

{create-class, create-factory, find-DOM-node}:React = require \react



module.exports = ({ReactivePlottable, plot, with-options, d3, fmap, unlift, is-highlighted}) ->

    to-react-element = (reactive-plottable, options) -> create-factory create-class do 

        render: ->
            React.DOM.div {
                ref: \stub
                style:
                    position: 'absolute'
                    top: 0
                    left: 0
                    right: 0
                    bottom: 0
            }

        component-did-mount: ->
            {change, fx, fxo, toggle} = @props
            (plot reactive-plottable `with-options` ({change, fx, fxo, toggle} <<< options)) (find-DOM-node @refs.stub), @props.lifted

        component-did-update: ->
            {change, fx, fxo, toggle} = @props
            (plot reactive-plottable `with-options` ({change, fx, fxo, toggle} <<< options)) (find-DOM-node @refs.stub), @props.lifted


    layout = (direction, cells) -->
        if "Array" != typeof! cells
            cells := drop 1, [].slice.call arguments
            
        
        new ReactivePlottable do 
            (view, results, {iden}:options, continuation) !-->

                rx-cells = cells |> map ({plotter}) ->
                    to-react-element plotter, options

                App = create-factory create-class do 
                    
                    render: ->        
                        
                        React.DOM.div null, do ~> (rx-cells `zip` [0 til cells.length]) |> map ([rx-cell, index]) ~>
                            change = ({t, v}) ~>
                                @set-state do 
                                    lifted: @state.lifted |> map (lifted-item) ~>
                                        
                                        if (iden . unlift <| lifted-item) == v 
                                            raw: unlift lifted-item
                                            status: {} <<< lifted-item.status <<< t
                                        else 
                                            lifted-item

                            # update the status of a lifted-item
                            fxo = (updated-status, lifted-item) -->
                                change {t: updated-status, v: iden . unlift <| lifted-item}

                            fx = (what, lifted-item) -->
                                o = match what
                                | 'highlight' => {highlight: true}
                                | 'dehighlight' => {highlight: false}
                                | _ => throw "unsupported fx what #{what}"

                                fxo o, lifted-item

                            toggle = (what, lifted-item) -->
                                status = lifted-item.status
                                o = match what
                                | 'highlight' => {highlight: !status.highlight}
                                | _ => throw "unsupported toggle what #{what}"
                                fxo o, lifted-item
                            
                            React.DOM.div do 
                                { 
                                    style: 
                                        width: '100%'
                                        height: '50%'
                                        position: 'relative'
                                    key: index
                                }, 
                                rx-cell do 
                                    lifted: @state.lifted
                                    change: change
                                    fx: fx
                                    fxo: fxo
                                    toggle: toggle
                            
                
                    get-initial-state: -> 
                        lifted: @props.lifted
                
                lifted = results.map -> 
                    raw: it
                    status: 
                        highlight: false
                    
                React.render (App {lifted}), view
            {
                iden: id
            }


    reactive-layout: layout

    reactive-layout-horizontal: layout \horizontal

    reactive-layout-vertical: layout \vertical