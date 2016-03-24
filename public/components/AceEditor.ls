{DOM:{div}}:React = require \react
ace = require \brace
require \brace/ext/language_tools
require \brace/ext/searchbox
require \brace/mode/livescript
require \brace/mode/javascript
require \brace/mode/sql
require \brace/mode/text
require \brace/theme/monokai

module.exports = React.create-class do

    display-name: \AceEditor

    # get-default-props :: a -> Props
    get-default-props: ->
        class-name: ""
        on-click: (->)
        editor-id: \editor
        mode: \ace/mode/livescript
        theme: \ace/theme/monokai
        value: ""
        wrap: false
        style: {}

    # render :: a -> ReactElement
    render: ->
        div do 
            id: @props.editor-id
            ref: \editor
            style: @props.style
            class-name: "ace-editor #{@props.class-name}"

    # component-did-mount :: a -> Void
    component-did-mount: !->
        editor = ace.edit @props.editor-id
            ..set-show-print-margin false
            ..set-options {enable-basic-autocompletion: true, scroll-past-end: 1.0}

            # ..commands.on \afterExec ({editor, command, args}) ->
            #     range = editor.get-selection-range!.clone!
            #     range.set-start range.start.row, 0
            #     line = editor.session.get-text-range range
            #     if command.name == \insertstring and 
            #        ((line.length == 1) or (/^\$[a-zA-Z]*$/.test args or /.*(\.|\s+[a-zA-Z\$\"\'\(\[\{])$/.test line))
            #         editor.execCommand \startAutocomplete 

            ..session.on \changeMode, (e, session) ~>
                if session.$worker and \ace/mode/javascript == session.get-mode!.$id
                    session.$worker.send "setOptions", [{ 
                        \-W095 : false
                        \-W025 : false
                        \esnext : true 
                    }]

            ..on \change, (, editor) ~> @props?.on-change editor.get-value!
            ..on \click, @props.on-click

        @process-props @props

    # component-did-update :: Props -> Void
    component-did-update: (prev-props) !->
        editor = ace.edit @props.editor-id
        editor.resize! if (prev-props.width != @props.width) or (prev-props.height != @props.height)

    # component-will-receive-props :: Props -> Void
    component-will-receive-props: (props) !-> @process-props props

    # process-props :: Props -> Void
    process-props: ({editor-id, mode, on-click, theme, value, wrap}:props?) !->
        editor = ace.edit editor-id
            ..get-session!.set-mode mode if !!mode
            ..get-session!.set-use-wrap-mode wrap if (typeof wrap != \undefined)
            ..set-theme theme if !!theme
        editor.set-value value, -1 if value != editor.get-value!
