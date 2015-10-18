CompleteDataSourceCue = (require \../../components/CompleteDataSourceCue.ls) <[host user password database]>
PartialDataSourceCue = require \../mssql/PartialDataSourceCue.ls

module.exports = {} <<< (require \../mssql/ui-protocol.ls) <<<

    # data-source-cue-popup-settings :: a -> DataSourceCuePopupSettings
    data-source-cue-popup-settings: ->
        supports-connection-string: true
        partial-data-source-cue-component: PartialDataSourceCue
        complete-data-source-cue-component: CompleteDataSourceCue