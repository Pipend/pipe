{DOM:{div}}:React = require \react
ace = require \brace
require \brace/theme/monokai
require \brace/mode/livescript
require \brace/ext/searchbox

module.exports = React.create-class {

    display-name: \AceEditor

    render: ->
        {id, width, height} = @.props
        div {id, style: {width, height}}

    component-did-mount: ->
        editor = ace.edit @.props.id
            ..on \change, (, editor) ~> @.props?.on-change editor.get-value!
            ..set-options {enable-basic-autocompletion: true}
            ..set-show-print-margin false
        @.process-props @.props

    component-did-update: (prev-props) ->
        editor = ace.edit @.props.id
        editor.resize! if prev-props.width * prev-props.height != @.props.width * @.props.height

    component-will-receive-props: ({id, value}:props) ->
        editor = ace.edit id        
        @.process-props props

    process-props: ({id, mode, theme, value}:props?) ->
        editor = ace.edit id
            ..get-session!.set-mode mode
            ..set-theme theme
        editor.set-value value if value != editor.get-value!

}