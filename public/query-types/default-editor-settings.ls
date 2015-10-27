# :: String -> AceEditorSettings
module.exports = (transpilation-language) ->
    syntax-highlighter = switch transpilation-language
    | \babel => \javascript
    | _ => transpilation-language
    mode: "ace/mode/#{syntax-highlighter}"
    theme: \ace/theme/monokai
    show-editor: true
    show-title: true