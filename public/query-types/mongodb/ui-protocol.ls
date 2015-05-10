DataSource = require \./DataSource.ls
{map, pairs-to-obj} = require \prelude-ls

editor-settings =
    mode: \ace/mode/livescript
    theme: \ace/theme/monokai

get-empty-data-source = ->
    {
        type: \mongodb
        connection-name: ""
        database: ""
        collection: ""
    }

module.exports = {

    get-empty-data-source

    get-query-editor-settings: -> editor-settings

    get-transformation-editor-settings: -> editor-settings

    get-presentation-editor-settings: -> editor-settings

    data-source-component: DataSource

}
