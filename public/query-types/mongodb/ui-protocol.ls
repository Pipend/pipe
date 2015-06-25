CompleteDataSourceCue = require \./CompleteDataSourceCue.ls
PartialDataSourceCue = require \./PartialDataSourceCue.ls

editor-settings =
    mode: \ace/mode/livescript
    theme: \ace/theme/monokai

module.exports = {
    data-source-cue-popup-settings: ->
        supports-connection-string: true
        partial-data-source-cue-component: PartialDataSourceCue
        complete-data-source-cue-component: CompleteDataSourceCue
    query-editor-settings: -> editor-settings
    transformation-editor-settings: -> editor-settings
    presentation-editor-settings: -> editor-settings
}