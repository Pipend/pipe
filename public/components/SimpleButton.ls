{DOM:{div}}:React = require \react

module.exports = React.create-class do

    display-name: \SimpleButton

    # get-default-props :: a -> Props
    get-default-props: ->
        pressed: false
        on-click: !->

    # render :: a -> UIState
    render: ->
        div do
            class-name: "simple-button #{if @props.pressed then \pressed else ''}"
            on-click: @props.on-click
            @props.label