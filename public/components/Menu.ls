{map} = require \prelude-ls
{key} = require \keymaster
{DOM:{a, div}}:React = require \react

module.exports = React.create-class {

    render: ->
        div {class-name: \menu},
            div {class-name: \logo}
            div {class-name: \buttons},
                @.props.items |> map ({action, hotkey, icon, label, type}) ->
                    if !!hotkey
                        key.unbind hotkey
                        key hotkey, action
                    a {on-click: ~> action!; false}, label

}
