{make-auto-completer} = require \../auto-complete-utils.ls

editor-settings =
    mode: \ace/mode/livescript
    theme: \ace/theme/monokai

module.exports = {
    data-source-cue-popup-settings: ->        
        supports-connection-string: false
    query-editor-settings: -> editor-settings
    transformation-editor-settings: -> editor-settings
    presentation-editor-settings: -> editor-settings
    make-auto-completer: (data-source-cue) ->
        make-auto-completer do
            data-source-cue
            ({keywords}:data) -> 
                Promise.resolve null
                # do nothing
            (query, {keywords, schema}) -> 
                Promise.resolve null
                # do nothing!
            (text, {schema, keywords, ast}) ->
                Promise.resolve []

}
