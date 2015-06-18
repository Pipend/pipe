require \brace/theme/twilight
DataSource = require \./DataSource.ls
{map, pairs-to-obj} = require \prelude-ls

editor-settings =
    mode: \ace/mode/livescript
    theme: \ace/theme/monokai

get-empty-data-source = ->
    {
        type: \mssql
        connection-name: ''
    }

module.exports = {

    get-empty-data-source

    get-query-editor-settings: -> editor-settings

    get-transformation-editor-settings: -> editor-settings

    get-presentation-editor-settings: -> editor-settings

    data-source-component: DataSource

}
