{map} = require \prelude-ls
{DOM:{a, div}}:React = require \react

module.exports = React.create-class {

    render: ->
        div {class-name: \menu},
            div {class-name: \logo}
            div {class-name: \buttons},
                @.props.items |> map ({action, hotkey, icon, label, type}) ->
                    if type == \separator then div {class-name: \separator} else a {on-click: ~> action!; false}, label

}
