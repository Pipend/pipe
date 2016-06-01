# :: String -> AceEditorSettings
module.exports = (transpilation-language) ->
    syntax-highlighter = switch transpilation-language
        | \babel => \javascript
        | _ => transpilation-language
    show-title: true
    show-content: true
    ace-editor-props:
        mode: "ace/mode/#{syntax-highlighter}"
        theme: \ace/theme/monokai