require! \./Checkbox.ls
{difference, each, filter, map, unique, sort} = require \prelude-ls
{key} = require \keymaster
{DOM:{a, div, input}}:React = require \react
{find-DOM-node} = require \react-dom
{cancel-event} = require \../utils.ls

module.exports = React.create-class do

    display-name: \Menu

    # render :: a -> ReactElement
    render: ->
        div do 
            id: \menu
            class-name: \menu
            @props.children
            div class-name: \buttons,
                @props.items |> map ({pressed, enabled, action, hotkey, icon, label, highlight, type}:item) ~>

                    # using ref for accessing the anchor tag from action listener
                    ref = label.replace /\s/g, '-' .to-lower-case!
                    
                    # action-listener :: Event -> Boolean
                    action-listener = (e) ~>
                        set-timeout do 
                            ~>
                                {offset-left, offset-width}:anchor-tag = find-DOM-node @refs[ref]
                                action offset-left, offset-width
                            0
                        cancel-event e

                    if !!hotkey
                        key.unbind hotkey
                        key hotkey, action-listener if enabled
                    
                    a do 
                        {
                            id: ref
                            key: ref
                            ref
                            style: (if !!highlight then {border-top: "1px solid #{highlight}"} else {}) <<< (if enabled then {} else {opacity: 0.5})
                            class-name: if pressed then \pressed else ''
                        } <<< if enabled then {on-click: action-listener} else {}
                        match type
                            | \toggle => React.create-element Checkbox, {checked: item.toggled}
                        label
                        
    # remove key listener for deleted menu items
    # component-will-receive-props :: Props -> Void
    component-will-receive-props: (props) !->

        # get-hotkeys :: Props -> [String]
        get-hotkeys = ({items}) -> 
            (items or [])
                |> filter -> !!it?.hotkey
                |> map (.hotkey)
                |> unique
                |> sort

        (get-hotkeys @props) `difference` get-hotkeys props
            |> each key.unbind
