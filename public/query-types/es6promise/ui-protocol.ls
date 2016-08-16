{make-auto-completer-default} = require \../auto-complete-utils.ls
editor-settings = require \../default-editor-settings.ls

module.exports =

    # data-source-cue-popup-settings :: a -> DataSourceCuePopupSettings
    data-source-cue-popup-settings: -> supports-connection-string: false

    # query-editor-settings :: String -> AceEditorSettings
    query-editor-settings: editor-settings

    # transformation-editor-settings :: String -> AceEditorSettings
    transformation-editor-settings: editor-settings

    # presentation-editor-settings :: String -> AceEditorSettings
    presentation-editor-settings: editor-settings

    # make-auto-completer :: (Promise p) => DataSourceCue -> p completions
    make-auto-completer: make-auto-completer-default
