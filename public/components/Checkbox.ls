{DOM:{div}}:React = require \react

module.exports = React.create-class do

    display-name: \Checkbox

    # get-default-props :: a -> Props
    get-default-props: ->
        checked: false

    # render :: a -> ReactElement
    render: ->
        div class-name: "checkbox #{if @props.checked then 'checked' else ''}"