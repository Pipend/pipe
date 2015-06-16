AceEditor = require \./AceEditor.ls
$ = require \jquery-browserify
{map} = require \prelude-ls
{DOM:{a, div, img}}:React = require \react

module.exports = React.create-class {

    display-name: \QueryListRoute

    render: ->
        div {class-name: \query-list-route},
            div {class-name: \menu}, 
                a {href: "branches", target: \_blank}, 'New query'
            div {class-name: \queries},
                @.state.branches |> map ({branch-id, latest-query:{query-id, query-title}, snapshot}?) ->
                    div {class-name: \query},
                        img {src: snapshot}
                        a {href: "branches/#{branch-id}/queries/#{query-id}"}, query-title
    
    get-initial-state: -> {branches: []}

    component-did-mount: ->
        self = @
        branches <- $.get \/apis/branches
        self.set-state {branches}

}