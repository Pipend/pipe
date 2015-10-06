CompleteDataSourceCue = (require \../../components/CompleteDataSourceCue.ls) <[host port database collection]>
PartialDataSourceCue = require \./PartialDataSourceCue.ls
{make-auto-completer} = require \../auto-complete-utils.ls

editor-settings = (transpilation-language) ->
    mode: "ace/mode/#{transpilation-language}"
    theme: \ace/theme/monokai



module.exports = {
    data-source-cue-popup-settings: ->
        supports-connection-string: true
        partial-data-source-cue-component: PartialDataSourceCue
        complete-data-source-cue-component: CompleteDataSourceCue
    query-editor-settings: (transpilation-language) -> 
        editor-settings transpilation-language
    transformation-editor-settings: (transpilation-language) -> 
        editor-settings transpilation-language
    presentation-editor-settings: (transpilation-language) -> 
        editor-settings transpilation-language
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