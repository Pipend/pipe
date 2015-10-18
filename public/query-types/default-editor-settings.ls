# :: String -> AceEditorSettings
module.exports = (transpilation-language) ->
    mode: "ace/mode/#{transpilation-language}"
    theme: \ace/theme/monokai
    show-editor: true
    show-title: true