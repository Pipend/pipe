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
        {left-document, right-document} = @.state

        # (Show a) => a -> String
        show = -> 
            match typeof! it
            | \String => it
            | \Object => JSON.stringify it, null, 4
            | _ => typeof! it

        div {class-name: \diff-route},
            <[query transformation presentation parameters dataSourceCue]>
                |> filter ~> !!right-document?[it] or !!left-document?[it]
                |> filter ~> !(right-document?[it] `is-equal-to-object` left-document?[it])
                |> map ~>
                    base-text-lines = string-as-lines show left-document[it]
                    new-text-lines = string-as-lines show right-document[it]
                    opcodes = (new SequenceMatcher base-text-lines, new-text-lines) .get_opcodes!
                    view = build-view {
                        base-text-lines
                        new-text-lines
                        opcodes
                        base-text-name: if !@props.query?.right then 'server' else @props.params.query-id
                        new-text-name: if !@props.query?.right then 'local storage' else @props.query.right
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
            ..done (left-document) ~>
                err, right-document <~ do ->
                    if !props?.query?.right 
                        (callback) -> callback null, (client-storage.get-document props.params.query-id) 
                    else 
                        (callback) -> $.getJSON "/apis/queries/#{props.query.right}"
                            ..done (document) -> callback null, document
                            ..fail ({response-text}) -> callback response-text
                @.set-state {left-document, right-document}
        
    component-did-mount: -> 
        @.load-documents @.props

    component-will-receive-props: (props) -> load-documents props

    get-initial-state: -> left-document: {}, right-document: {}

}