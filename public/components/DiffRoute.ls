AceEditor = require \./AceEditor.ls
{filter, map} = require \prelude-ls
{DOM:{div, h1, table}}:React = require \react
$ = require \jquery-browserify
client-storage = require \../client-storage.ls
{is-equal-to-object} = require \../utils.ls
{build-view, SequenceMatcher, string-as-lines}:diff = require \jsdifflib

module.exports = React.create-class {

    display-name: \DiffRoute

    render: ->
        {local-document, remote-document} = @.state
        div {class-name: \diff-route},
            <[query transformation presentation parameters dataSource]>
                |> filter ~> !!local-document?[it] or !!remote-document?[it]
                |> filter ~> !(local-document?[it] `is-equal-to-object` remote-document?[it])
                |> map ~>
                    base-text-lines = string-as-lines remote-document[it]
                    new-text-lines = string-as-lines local-document[it]
                    opcodes = (new SequenceMatcher base-text-lines, new-text-lines) .get_opcodes!
                    view = build-view {
                        base-text-lines
                        new-text-lines
                        opcodes
                        base-text-name: \server
                        new-text-name: 'local storage'
                        context-size: null
                        view-type: 1
                    }
                    div null,
                        h1 null, it
                        table do
                            class-name: \diff 
                            dangerously-set-inner-HTML: __html: view.inner-HTML

    load-documents: (props) ->                
        $.getJSON "/apis/queries/#{props.params.query-id}"
            ..done (remote-document) ~>
                @.set-state do
                    local-document: client-storage.get-document props.params.query-id
                    remote-document: remote-document

    component-did-mount: -> 
        @.load-documents @.props

    component-will-receive-props: (props) -> load-documents props

    get-initial-state: -> local-document: {}, remote-document: {}

}