{filter, find, fold, map, sort-by} = require \prelude-ls
{DOM:{button, circle, div, g, h1, line, path, svg}}:React = require \react

module.exports = React.create-class do 

    render: ->
        div { }, @state.urls.map (u) -> button {}, "A"
        #h1 null, "Hello"

    get-initial-state: -> {
        urls: [""]
    }
