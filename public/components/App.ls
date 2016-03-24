{create-class, DOM:{div}} = require \react

module.exports = create-class do

    display-name: \App

    # render :: () -> ReactElement
    render: ->
        div class-name: \app, @props.children