AceEditor = require \./AceEditor.ls
Menu = require \./Menu.ls
{map} = require \prelude-ls
{DOM:{div, input}}:React = require \react

module.exports = React.create-class {

    display-name: \QueryRoute

    render: ->        
        div {class-name: \query-route},
            React.create-element do 
                Menu
                    items:
                        * icon: \n, label: \New, action: -> window.open \http://www.google.com, \_blank                            
                        * icon: \f, label: \Fork, action: ->
                        * hotkey: "command + s", icon: \s, label: \Save, action: ->
                        * icon: \r, label: \Reset, action: ->
                        * icon: \c, label: \Cache, action: ->
                        * hotkey: "command + enter", icon: \e, label: \Execute, action: ->
                        * icon: \t, label: \Tree, action: ->
                        * icon: \h, label: \Share, action: ->
                        * icon: \c, label: \Connection, action: ->
                        * icon: \p, label: \Parameters, action: ->
                        * icon: \t, label: \Tags, action: ->
            div {class-name: \content},
                div {class-name: \editors, style: {width: 550}},
                    [
                        {
                            id: \query
                            editable-title: true
                            resizable: true
                        }
                        {
                            id: \transformation
                            title: \Transformation
                            editable-title: false
                            resizable: true
                        }
                        {
                            id: \presentation
                            title: \Presentation
                            editable-title: false
                            resizable: false
                        }
                    ] |> map ({editable-title, id, resizable, title}:editor) ~>
                        div {class-name: \editor},
                            div {class-name: \editor-title},
                                if editable-title 
                                    input {
                                        type: \text
                                        value: title or @.state["#{id}Title"]
                                        on-change: ({current-target:{value}}) ~> @.set-state {"#{id}Title" : value}
                                    }
                                else
                                    title
                            React.create-element AceEditor, {
                                id: "#{id}-editor"
                                mode: \ace/mode/livescript
                                theme: \ace/theme/monokai
                                value: @.state[id]
                                height: @.state["#{id}EditorHeight"]
                                on-change: (value) ~> @.set-state {"#{id}" : value}
                            }
                            if resizable 
                                div {class-name: \resize-handle}
                div {class-name: \resize-handle}
                div {class-name: \output, style: {left: 0, top: 0, width: 0, height: 0}}

    get-initial-state: ->
        {
            query: ""
            query-editor-height: 300
            query-title: "Untitled query"
            transformation: ""
            transformation-editor-height: 324
            presentation: ""
            presentation-editor-height: 240
        }



}