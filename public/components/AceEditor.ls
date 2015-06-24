{DOM:{div}}:React = require \react
ace = require \brace
require \brace/theme/monokai
require \brace/mode/livescript
require \brace/ext/searchbox

module.exports = React.create-class {

    display-name: \AceEditor

    render: ->
        {editor-id, width, height} = @.props
        div {id: editor-id, style: {width, height}}

    component-did-mount: ->
        editor = ace.edit @.props.editor-id
            ..on \change, (, editor) ~> @.props?.on-change editor.get-value!
            ..set-options {enable-basic-autocompletion: true}
            ..set-show-print-margin false
            ..commands.on \afterExec ({editor, command, args}) ->
                range = editor.getSelectionRange!.clone!
                range.setStart range.start.row, 0
                line = editor.session.getTextRange range
                editor.execCommand \startAutocomplete if command.name == "insertstring" and ((line.length == 1) or (/^\$[a-zA-Z]*$/.test args or /.*(\.|\s+[a-zA-Z\$\"\'\(\[\{])$/.test line))
        @.process-props {mode: \ace/mode/livescript, theme: \ace/theme/monokai} <<< @.props

    component-did-update: (prev-props) ->
        editor = ace.edit @.props.editor-id
        editor.resize! if prev-props.width * prev-props.height != @.props.width * @.props.height

    component-will-receive-props: ({editor-id, value}:props) ->
        editor = ace.edit editor-id        
        @.process-props props

    process-props: ({editor-id, mode, theme, value}:props?) ->
        editor = ace.edit editor-id
            ..get-session!.set-mode mode if !!mode
            ..set-theme theme if !!theme
        editor.set-value value, -1 if value != editor.get-value!

}