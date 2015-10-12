{DOM:{button}}:React = require \react

module.exports = React.create-class do

    display-name: \SimpleButton

    # get-default-props :: a -> Props
    get-default-props: ->
        # id :: String
        color: \green
        on-click: !->
        pressed: false
        style: {}

    # render :: a -> UIState
    render: ->
        button do
            id: @props.id
            class-name: "simple-button #{@props.color} #{if @props.pressed then \pressed else ''}"
            on-click: @props.on-click
            style: @props.style
            @props.children