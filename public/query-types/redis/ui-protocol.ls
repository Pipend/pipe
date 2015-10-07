{make-auto-completer} = require \../auto-complete-utils.ls

client-side-editor-settings = (transpilation-language) ->
    mode: "ace/mode/#{transpilation-language}"
    theme: \ace/theme/monokai

module.exports =
    
    data-source-cue-popup-settings: -> supports-connection-string: false

    query-editor-settings: -> visible: false

    transformation-editor-settings: (transpilation-language) -> client-side-editor-settings transpilation-language

    presentation-editor-settings: (transpilation-language) -> client-side-editor-settings transpilation-language

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