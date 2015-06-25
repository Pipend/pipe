{DOM:{div, label, option, select}}:React = require \react
{map} = require \prelude-ls

module.exports = React.create-class {

    render: ->
        {disabled, value, options} = @props
        div null,
            label null, @props.label
            select {disabled, value, on-change: ({current-target:{value}}) ~> @props.on-change value},
                options |> map -> option {key: it.value, value: it.value}, it.label
                
}