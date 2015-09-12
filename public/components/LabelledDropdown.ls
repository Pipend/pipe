{create-factory, DOM:{div, label, option, select, span}}:React = require \react
{find, map} = require \prelude-ls
SimpleSelect = create-factory (require \react-selectize).SimpleSelect

module.exports = React.create-class do

    render: ->
        {disabled, value, options} = @props
        div null,
            label null, @props.label
            SimpleSelect do 
                disabled: disabled
                value: 
                    label: (options ? []) |> find (.value == value) |> (?.label)
                    value: value
                restore-on-backspace: -> it.label.substr 0, it.label.length - 1
                render-value: (, {label}) ~>
                    div class-name: \simple-value,
                        span null, label
                on-value-change: ({value}?, callback) ~> 
                    @props.on-change value
                    callback!
                options: options
                
