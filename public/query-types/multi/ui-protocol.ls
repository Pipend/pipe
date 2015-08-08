editor-settings = (transpilation-language) ->
    mode: "ace/mode/#{transpilation-language}"
    theme: \ace/theme/monokai

module.exports = {
    data-source-cue-popup-settings: ->
        supports-connection-string: false
    query-editor-settings: (transpilation-language) -> 
        editor-settings transpilation-language
    transformation-editor-settings: (transpilation-language) -> 
        editor-settings transpilation-language
    presentation-editor-settings: (transpilation-language) -> 
        editor-settings transpilation-language
}