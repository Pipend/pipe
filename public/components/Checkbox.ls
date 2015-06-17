{DOM:{div}}:React = require \react

module.exports = React.create-class {

    render: ->
        div {class-name: "checkbox #{if @.props.checked then 'checked' else ''}"}

}
