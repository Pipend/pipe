editor-settings =
    mode: \ace/mode/livescript
    theme: \ace/theme/monokai

module.exports = {
    data-source-cue-popup-settings: ->        
        supports-connection-string: false
    query-editor-settings: -> editor-settings
    transformation-editor-settings: -> editor-settings
    presentation-editor-settings: -> editor-settings
}
