CompleteDataSourceCue = require \./CompleteDataSourceCue.ls
PartialDataSourceCue = require \./PartialDataSourceCue.ls

editor-settings =
    mode: \ace/mode/livescript
    theme: \ace/theme/monokai

module.exports = {

    get-query-editor-settings: -> editor-settings

    get-transformation-editor-settings: -> editor-settings

    get-presentation-editor-settings: -> editor-settings

    partial-data-source-cue-component: PartialDataSourceCue

    complete-data-source-cue-component: CompleteDataSourceCue

}
