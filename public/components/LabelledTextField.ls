{DOM:{div, input, label}}:React = require \react

module.exports = React.create-class {

    render: ->
        div null,
            label null, @props.label
            input do
                type: \text
                value: @props.value
                on-change: ({current-target:{value}}) ~>
                    @props.on-change value

}