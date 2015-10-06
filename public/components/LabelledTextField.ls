{DOM:{div, input, label}}:React = require \react

module.exports = React.create-class do

    display-name: \LabelledTextField

    # get-default-props :: a -> Props
    get-default-props: ->
        label: ""
        value: ""
        on-change: (value) !->

    # render :: a -> ReactElement
    render: ->
        div class-name: \labelled-text-field,
            label null, @props.label
            input do
                type: \text
                value: @props.value
                on-change: ({current-target:{value}}) ~>
                    @props.on-change value