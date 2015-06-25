{DOM:{div}}:React = require \react

module.exports = React.create-class {

    render: ->
        div do
            {
                class-name: "simple-button #{if @props.pressed then \pressed else ''}"
                on-click: @props?.on-click
            }
            @props.label

}