{map, camelize} = require \prelude-ls
CompleteDataSourceCue = (require \../../components/CompleteDataSourceCue.ls) (map camelize, <[host port database collection]>)
PartialDataSourceCue = require \./PartialDataSourceCue.ls
{make-auto-completer-default} = require \../auto-complete-utils.ls
editor-settings = require \../default-editor-settings.ls

module.exports =

    # data-source-cue-popup-settings :: a -> DataSourceCuePopupSettings
    data-source-cue-popup-settings: ->
        supports-connection-string: true
        partial-data-source-cue-component: PartialDataSourceCue
        complete-data-source-cue-component: CompleteDataSourceCue

    # query-editor-settings :: String -> AceEditorSettings
    query-editor-settings: editor-settings

    # transformation-editor-settings :: String -> AceEditorSettings
    transformation-editor-settings: editor-settings

    # presentation-editor-settings :: String -> AceEditorSettings
    presentation-editor-settings: editor-settings

    # make-auto-completer :: (Promise p) => DataSourceCue -> p completions
    make-auto-completer: make-auto-completer-default