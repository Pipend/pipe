CompleteDataSourceCue = (require \../../components/CompleteDataSourceCue.ls) <[server user password database]>
PartialDataSourceCue = require \./PartialDataSourceCue.ls

client-side-editor-settings = (transpilation-language) ->
    mode: "ace/mode/#{transpilation-language}"
    theme: \ace/theme/monokai

server-side-editor-settings =
    mode: \ace/mode/sql
    theme: \ace/theme/monokai

module.exports = {
    data-source-cue-popup-settings: ->
        supports-connection-string: true
        partial-data-source-cue-component: PartialDataSourceCue
        complete-data-source-cue-component: CompleteDataSourceCue
    query-editor-settings: (_) -> server-side-editor-settings
    transformation-editor-settings: (transpilation-language) -> 
        client-side-editor-settings transpilation-language
    presentation-editor-settings: (transpilation-language) -> 
        client-side-editor-settings transpilation-language
}
