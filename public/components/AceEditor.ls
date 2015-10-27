{DOM:{div}}:React = require \react
ace = require \brace
require \brace/theme/monokai
require \brace/mode/livescript
require \brace/mode/javascript
require \brace/mode/sql
require \brace/mode/text
require \brace/ext/searchbox

module.exports = React.create-class do

    display-name: \AceEditor

    # get-default-props :: a -> Props
    get-default-props: ->
        on-click: (->)
        editor-id: \editor
        mode: \ace/mode/livescript
        theme: \ace/theme/monokai
        value: ""
        wrap: false
        width: 400
        height: 300

    # render :: a -> ReactElement
    render: ->
        div do 
            id: @props.editor-id
            ref: \editor
            style: 
                width: @props.width
                height: @props.height

    # component-did-mount :: a -> Void
    component-did-mount: !->
        editor = ace.edit @props.editor-id
            ..on \change, (, editor) ~> @props?.on-change editor.get-value!
            ..set-options {enable-basic-autocompletion: true}
            ..set-show-print-margin false
            ..commands.on \afterExec ({editor, command, args}) ->
                range = editor.getSelectionRange!.clone!
                range.setStart range.start.row, 0
                line = editor.session.getTextRange range
                editor.execCommand \startAutocomplete if command.name == "insertstring" and ((line.length == 1) or (/^\$[a-zA-Z]*$/.test args or /.*(\.|\s+[a-zA-Z\$\"\'\(\[\{])$/.test line))
            ..session.on \changeMode, (e, session) ~>
                if "ace/mode/javascript" == session.getMode!.$id
                    if !!session.$worker
                        session.$worker.send "setOptions", [ { "-W095": false, "-W025": false, 'esnext': true } ]
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
