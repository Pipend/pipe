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
window.d3 = require \d3-browserify
{compile-and-execute-livescript} = require \../utils.ls
transformation-context = require \../transformation/context.ls
presentation-context = require \../presentation/context.ls

module.exports = React.create-class {

    display-name: \QueryRoute

    render: ->
        {
            data-source
            query
            query-title
            transformation
            presentation
            parameters
            editor-width
            show-popup
        } = @.state

        toggle-popup = (popup-name) ~> @.set-state {show-popup: if @.state.show-popup == popup-name then '' else popup-name}

        div {class-name: \query-route},
            React.create-element do 
                Menu
                {
                    ref: \menu
                    items:
                        * icon: \n, label: \New, action: ~>
                        * icon: \f, label: \Fork, action: ~>
                        * hotkey: "command + s", icon: \s, label: \Save, action: ~>
                        * icon: \r, label: \Reset, action: ~>
                        * icon: \c, label: \Cache, action: ~>
                        * hotkey: "command + enter", icon: \e, label: \Execute, action: ~>

                            # clean existing presentation
                            $ @.refs.presentation.get-DOM-node! .empty!

                            display-error = (err) ~>
                                pre = $ "<pre/>"
                                pre.html err.to-string!
                                $ @.refs.presentation.get-DOM-node! .empty! .append pre

                            $.ajax {
                                type: \post
                                url: \/apis/execute
                                content-type: 'application/json; charset=utf-8'
                                data-type: \json
                                data: JSON.stringify {document: @.document-from-state @.state}
                                success: (query-result) ~>

                                    if !!parameters and parameters.trim!.length > 0
                                        [err, parameters-object] = compile-and-execute-livescript parameters, {}
                                        console.log err if !!err

                                    parameters-object ?= {}

                                    [err, func] = compile-and-execute-livescript "(#transformation\n)", {} <<< transformation-context! <<< parameters-object <<< (require \prelude-ls)
                                    return display-error "ERROR IN THE TRANSFORMATION COMPILATION: #{err}" if !!err
                                    
                                    try
                                        transformed-result = func query-result
                                    catch ex
                                        return display-error "ERROR IN THE TRANSFORMATION EXECUTAION: #{ex.to-string!}"

                                    [err, func] = compile-and-execute-livescript do 
                                        "(#presentation\n)"
                                        {d3, $} <<< transformation-context! <<< presentation-context! <<< parameters-object <<< (require \prelude-ls)
                                    return display-error "ERROR IN THE PRESENTATION COMPILATION: #{err}" if !!err
                                    
                                    try
                                        func @.refs.presentation.get-DOM-node!, transformed-result
                                    catch ex
                                        return display-error "ERROR IN THE PRESENTATION EXECUTAION: #{ex.to-string!}"
                                    

                            }

                        * icon: \c, label: 'Data Source', action: ~> toggle-popup \data-source-popup
                        * icon: \p, label: \Parameters, action: ~> toggle-popup \parameters-popup
                        * icon: \t, label: \Tags, action: ~>
                        * icon: \t, label: \VCS, action: ~>
                        * icon: \h, label: \Share, action: ~> 
                    }

            match show-popup
                | \data-source-popup =>
                    React.create-element do
                        DataSourcePopup
                        {
                            data-source: data-source
                            data-source-component: ui-protocol[data-source.type].data-source-component
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
                div {class-name: \editors, style: {width: editor-width}},
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
                            } <<< ui-protocol[data-source.type]?[camelize "get-#{editor-id}-editor-settings"]!
                            if resizable 
                                div {
                                    class-name: \resize-handle
                                    on-mouse-down: (e) ~>
                                        initialY = e.pageY
                                        initial-height = @.state["#{editor-id}EditorHeight"]
                                        $ window .on \mousemove, ({pageY}) ~> @.set-state {"#{editor-id}EditorHeight": initial-height + (pageY - initialY)}
                                        $ window .on \mouseup, -> $ window .off \mousemove .off \mouseup
                                }
                div {
                    class-name: \resize-handle
                    ref: \resize-handle
                    on-mouse-down: (e) ~>
                        initialX = e.pageX
                        initial-width = @.state.editor-width
                        $ window .on \mousemove, ({pageX}) ~> 
                            <~ @.set-state {editor-width: initial-width + (pageX - initialX)}
                            @.update-presentation-size!
                        $ window .on \mouseup, -> $ window .off \mousemove .off \mouseup
                }

                # operations on this div are not controlled by react
                div {ref: \presentation, class-name: \presentation}

    get-initial-state: ->
        {
            query-id: 0
            parent-id: 0
            branch-id: 0
            tree-id: 0
            data-source: ui-protocol[\mongodb].get-empty-data-source!
            query: ""
            query-title: "Untitled query"
            transformation: ""
            presentation: ""
            parameters: ""
            editor-width: 550
            query-editor-height: 300
            transformation-editor-height: 324
            presentation-editor-height: 240
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
        ui
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
            editor-width: ui?.editor?.width or @.state.editor-width
            query-editor-height: ui?.query-editor?.height or @.state.query-editor-height
            transformation-editor-height: ui?.transformation-editor?.height or @.state.transformation-editor-height
            presentation-editor-height: ui?.presentation-editor?.height or @.state.presentation-editor-height
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
            ui:
                editor:
                    width: editor-width
                query-editor:
                    height: query-editor-height
                transformation-editor:
                    height: transformation-editor-height
                presentation-editor:
                    height: presentation-editor-height
        }    

    component-did-mount: ->
        $.getJSON "/apis/queries/#{@.props.params.query-id}"
            ..done (document) ~> @.set-state @.state-from-document document    
        $ window .on \resize, ~> @.update-presentation-size!
        @.update-presentation-size!

    update-presentation-size: ->
        left = @.state.editor-width + 10
        @.refs.presentation.get-DOM-node!.style <<< {
            left
            width: window.inner-width - left
            height: window.inner-height - @.refs.menu.get-DOM-node!.offset-height
        }

}