Checkbox = require \./Checkbox.ls
{difference, each, filter, map, unique, sort} = require \prelude-ls
{key} = require \keymaster
{DOM:{a, div, input}}:React = require \react
{cancel-event} = require \../utils.ls

module.exports = React.create-class {

    render: ->
        div {class-name: \menu},            
            @.props.children
            div {class-name: \buttons},
                @.props.items |> map ({pressed, enabled, action, hotkey, icon, label, highlight, type}:item) ~>

                    # using ref for accessing the anchor tag from action listener
                    ref = label.replace /\s/g, '' .to-lower-case!
                    
                    action-listener = (e) ~>
                        {offset-left, offset-width}:anchor-tag = @.refs[ref].get-DOM-node!
                        action offset-left, offset-width
                        cancel-event e

                    if !!hotkey
                        key.unbind hotkey
                        key hotkey, action-listener if enabled
                    
                    a do 
                        {
                            key: ref
                            ref
                            style: (if !!highlight then {border-top: "1px solid #{highlight}"} else {}) <<< (if enabled then {} else {opacity: 0.5})
                            class-name: if pressed then \pressed else ''
                        } <<< if enabled then {on-click: action-listener} else {}
                        match type
                            | \toggle => React.create-element Checkbox, {checked: item.toggled}
                        label
                        
    # remove key listener for deleted menu items
    component-will-receive-props: (props) ->
        get-hotkeys = ({items}) -> 
            (items or [])
                |> filter -> !!it?.hotkey
                |> map (.hotkey)
                |> unique
                |> sort
        (get-hotkeys @.props) `difference` get-hotkeys props
            |> each key.unbind

}
