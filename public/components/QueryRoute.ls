AceEditor = require \./AceEditor.ls
DataSourcePopup = require \./DataSourcePopup.ls
{default-type} = require \../../config.ls
Menu = require \./Menu.ls
{camelize, map} = require \prelude-ls
{DOM:{div, input}}:React = require \react
ui-protocol =
    mongodb: require \../query-types/mongodb/ui-protocol.ls
    mssql: require \../query-types/mssql/ui-protocol.ls
$ = require \jquery-browserify

module.exports = React.create-class {

    display-name: \QueryRoute

    render: ->

        toggle-popup = (popup-name) ~> @.set-state {show-popup: if @.state.show-popup == popup-name then '' else popup-name}

        div {class-name: \query-route},
            React.create-element do 
                Menu
                    items:
                        * icon: \n, label: \New, action: ~>
                        * icon: \f, label: \Fork, action: ~>
                        * hotkey: "command + s", icon: \s, label: \Save, action: ~>
                        * icon: \r, label: \Reset, action: ~>
                        * icon: \c, label: \Cache, action: ~>
                        * hotkey: "command + enter", icon: \e, label: \Execute, action: ~>
                            $.ajax {
                                type: \post
                                url: \/apis/execute
                                content-type: 'application/json; charset=utf-8'
                                data-type: \json
                                data: JSON.stringify {document: @.document-from-state @.state}
                                success: (query-result) ~>
                                    
                            }
                        * icon: \c, label: 'Data Source', action: ~> toggle-popup \data-source-popup
                        * icon: \p, label: \Parameters, action: ~> toggle-popup \parameters-popup
                        * icon: \t, label: \Tags, action: ~>
                        # * icon: \t, label: \VCS, action: ~>
                        # * icon: \h, label: \Share, action: ~> 
                        
            match @.state.show-popup
                | \data-source-popup =>
                    React.create-element do
                        DataSourcePopup
                        {
                            data-source: @.state.data-source
                            data-source-component: ui-protocol[@.state.data-source.type].data-source-component
                            on-change: (data-source) ~> @.set-state {data-source}
                        }
                | \parameters-popup =>
                    div {class-name: 'parameters-popup popup'},
                        React.create-element AceEditor, {
                            editor-id: "parameters-editor"                            
                            value: @.state.parameters
                            width: 400
                            height: 300                            
                            on-change: (value) ~> @.set-state {parameters : value}
                        }

            div {class-name: \content},
                div {class-name: \editors, style: {width: 550}},
                    [
                        {
                            editor-id: \query
                            editable-title: true
                            resizable: true
                        }
                        {
                            editor-id: \transformation
                            title: \Transformation
                            editable-title: false
                            resizable: true
                        }
                        {
                            editor-id: \presentation
                            title: \Presentation
                            editable-title: false
                            resizable: false
                        }
                    ] |> map ({editable-title, editor-id, resizable, title}:editor) ~>
                        div {class-name: \editor, key: editor-id},
                            div {class-name: \editor-title},
                                if editable-title 
                                    input {
                                        type: \text
                                        value: title or @.state["#{editor-id}Title"]
                                        on-change: ({current-target:{value}}) ~> @.set-state {"#{editor-id}Title" : value}
                                    }
                                else
                                    title
                            React.create-element AceEditor, {
                                editor-id: "#{editor-id}-editor"                                
                                value: @.state[editor-id]
                                height: @.state["#{editor-id}EditorHeight"]
                                on-change: (value) ~> @.set-state {"#{editor-id}" : value}
                            } <<< ui-protocol[@.state.data-source.type]?[camelize "get-#{editor-id}-editor-settings"]!
                            if resizable 
                                div {class-name: \resize-handle}
                div {class-name: \resize-handle}
                div {ref: \output, class-name: \output, style: {left: 0, top: 0, width: 0, height: 0}}

    get-initial-state: ->
        {
            query-id: 0
            parent-id: 0
            branch-id: 0
            tree-id: 0
            data-source: ui-protocol[\mongodb].get-empty-data-source!
            query: ""
            query-editor-height: 300
            query-title: "Untitled query"
            transformation: ""
            transformation-editor-height: 324
            presentation: ""
            presentation-editor-height: 240
            parameters: ""
            show-popup: null            
        }

    # converting the document to a flat object makes it easy to work with 
    state-from-document: ({
        query-id
        parent-id
        branch-id
        tree-id
        data-source
        query-title
        query
        transformation
        presentation
        parameters
        ui:{
            editor-width
            query-editor-height
            transformation-editor-height
            presentation-editor-height
        }
    }?) ->
        @.set-state {
            query-id
            parent-id
            branch-id
            tree-id
            data-source
            query-title
            query
            transformation
            presentation
            parameters
            # editor-width
            # query-editor-height
            # transformation-editor-height
            # presentation-editor-height
        }

    document-from-state: (state) ->
        {
            query-id
            parent-id
            branch-id
            tree-id
            data-source
            query-title
            query
            transformation
            presentation
            parameters
            editor-width
            query-editor-height
            transformation-editor-height
            presentation-editor-height
        } = state
        {
            query-id
            parent-id
            branch-id
            tree-id
            data-source
            query-title
            query
            transformation
            presentation
            parameters
            ui:{
                editor-width
                query-editor-height
                transformation-editor-height
                presentation-editor-height
            }
        }    

    component-did-mount: ->
        $.getJSON "/apis/queries/#{@.props.params.query-id}"
            ..done (document) ~> @.set-state @.state-from-document document


}