Checkbox = require \./Checkbox.ls
{difference, each, filter, map, unique, sort} = require \prelude-ls
{key} = require \keymaster
{DOM:{a, div, input}}:React = require \react
{cancel-event} = require \../utils.ls

module.exports = React.create-class {

    render: ->
        div {class-name: \menu},
            div {class-name: \logo}
            div {class-name: \buttons},
                @.props.items |> map ({action, hotkey, icon, label, highlight, type}:item) ~>

                    # using ref for accessing the anchor tag from hotkey listener
                    ref = label.replace /\s/g, '' .to-lower-case!
                    
                    action-listener = (e) ~>
                        action @.refs[ref].get-DOM-node!.offset-left
                        cancel-event e

                    if !!hotkey
                        key.unbind hotkey
                        key hotkey, action-listener
                    
                    a do 
                        {
                            key: ref
                            ref
                            on-click: action-listener
                            style: if !!highlight then {border-top: "1px solid #{highlight}"} else {}
                        }
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
