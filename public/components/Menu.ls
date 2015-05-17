{map} = require \prelude-ls
{key} = require \keymaster
{DOM:{a, div}}:React = require \react
{cancel-event} = require \../utils.ls

module.exports = React.create-class {

    render: ->
        div {class-name: \menu},
            div {class-name: \logo}
            div {class-name: \buttons},
                @.props.items |> map ({action, hotkey, icon, label, type, highlight}) ~>

                    # using ref for accessing the anchor tag from hotkey listener
                    ref = label.replace /\s/g, '' .to-lower-case!
                    
                    if !!hotkey
                        key.unbind hotkey
                        key hotkey, ~> 
                            action @.refs[ref].get-DOM-node!.offset-left
                            cancel-event it

                    a do 
                        {
                            key: ref
                            ref
                            on-click: (e) ~> 
                                action @.refs[ref].get-DOM-node!.offset-left
                                cancel-event e
                            style: if !!highlight then {border-top: "1px solid #{highlight}"} else {}
                        }
                        label

}
