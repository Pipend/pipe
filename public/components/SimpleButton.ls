{DOM:{button}}:React = require \react

module.exports = React.create-class do

    display-name: \SimpleButton

    # get-default-props :: a -> Props
    get-default-props: ->
        color: \green
        pressed: false
        on-click: !->

    # render :: a -> UIState
    render: ->
        button do
            class-name: "simple-button #{@props.color} #{if @props.pressed then \pressed else ''}"
            on-click: @props.on-click
            @props.children