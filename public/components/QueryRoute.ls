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
{compile-and-execute-livescript, generate-uid} = require \../utils.ls
transformation-context = require \../transformation/context.ls
presentation-context = require \../presentation/context.ls
SharePopup = require \./SharePopup.ls
{Navigation} = require \react-router
client-storage = require \../client-storage.ls
ConflictDialog = require \./ConflictDialog.ls

module.exports = React.create-class {

    display-name: \QueryRoute

    mixins: [Navigation]

    render: ->
        {
            query-id
            branch-id
            data-source
            query
            query-title
            transformation
            presentation
            parameters
            editor-width
            popup-left
            show-popup
            queries-in-between
            show-conflict-dialog
        } = @.state

        toggle-popup = (button-left, popup-name) ~> @.set-state {
            popup-left: button-left - 100
            show-popup: if @.state.show-popup == popup-name then '' else popup-name            
        }

        menu-items = 
            * icon: \n, label: \New, action: ~> window.open "/branches", \_blank
            * icon: \f, label: \Fork, action: ~>

                # throw an error if the document cannot be forked (i.e when the branch id is already local or localFork)
                {query-id, parent-id, tree-id, query-title}:document? = @.document-from-state!
                throw "cannot fork a local query, please save the query before forking it" if @.props.params.branch-id in <[local localFork]>

                # create a new copy of the document, update as required then save it to local storage
                {query-id}:forked-document = {} <<< document <<< {
                    query-id: generate-uid!
                    parent-id: query-id
                    branch-id: \localFork
                    tree-id
                    query-title: "Copy of #{query-title}"
                }
                client-storage.save-document query-id, forked-document

                # by redirecting the user to a localFork branch we cause the document to be loaded from local-storage
                window.open "/branches/localFork/queries/#{query-id}", \_blank

            * hotkey: "command + s", icon: \s, label: \Save, action: ~>

                # return if the document has not changed

                uid = generate-uid! 
                {query-id, tree-id}:document = @.document-from-state!

                # a new query-id is generate at the time of save, parent-id is set to the old query-id
                # expect in the case of a forked-query (whose parent-id is saved in the local-storage at the time of fork)
                document-to-save = {} <<< document <<< {
                    query-id: uid
                    parent-id: switch @.props.params.branch-id
                        | \local => null
                        | \local-fork => parent-id
                        | _ => query-id
                    branch-id: if (@.props.params.branch-id.index-of \local) == 0 then uid else @.props.params.branch-id
                    tree-id: tree-id or uid
                }

                $.ajax {
                    type: \post
                    url: \/apis/save
                    content-type: 'application/json; charset=utf-8'
                    data-type: \json
                    data: JSON.stringify document-to-save
                }
                    ..done ({query-id, branch-id}:saved-document) ~>
                        @.set-state saved-document
                        @.replace-with "/branches/#{branch-id}/queries/#{query-id}"
                    ..fail ({response-text}:err?) ~>
                        {queries-in-between}? = JSON.parse response-text
                        @.set-state {show-conflict-dialog: true, queries-in-between}
                false

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
                    data: JSON.stringify {document: @.document-from-state!}
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

            * icon: \c, label: 'Data Source', action: (button-left) ~> toggle-popup button-left, \data-source-popup
            * icon: \p, label: \Parameters, action: (button-left) ~> toggle-popup button-left, \parameters-popup
            * icon: \t, label: \Tags, action: ~>
            * icon: \t, label: \VCS, action: ~>

        show-share = !!@.props.params.branch-id and !(@.props.params.branch-id in <[local localFork]>) and !!@.props.params.query-id

        div {class-name: \query-route},
            React.create-element Menu, {
                ref: \menu
                items: menu-items ++ if show-share then {icon: \h, label: \Share, action: (button-left) ~> toggle-popup button-left, \share-popup} else []
            }            

            match show-popup
                | \data-source-popup =>
                    React.create-element do
                        DataSourcePopup
                        {
                            left: popup-left
                            data-source: data-source
                            data-source-component: ui-protocol[data-source.type].data-source-component
                            on-change: (data-source) ~> @.set-state {data-source}
                        }
                | \parameters-popup =>
                    div {class-name: 'parameters-popup popup', style: {left: popup-left}},
                        React.create-element AceEditor, {
                            editor-id: "parameters-editor"                            
                            value: @.state.parameters
                            width: 400
                            height: 300                            
                            on-change: (value) ~> @.set-state {parameters : value}
                        }
                | \share-popup =>
                    [err, parameters-object] = compile-and-execute-livescript parameters
                    React.create-element do 
                        SharePopup
                        {
                            host: window.location.host
                            left: popup-left
                            base-url: "http://localhost:4081"
                            query-id
                            branch-id
                            parameters: if !!err then {} else parameters-object
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

        if !!show-conflict-dialog
            React.create-element ConflictDialog, {queries-in-between}
        
    get-initial-state: ->
        {
            query-id: null
            parent-id: null
            branch-id: null
            tree-id: null
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
            show-conflict-dialog: false
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
            editor-width: ui?.editor?.width or @.state.editor-width
            query-editor-height: ui?.query-editor?.height or @.state.query-editor-height
            transformation-editor-height: ui?.transformation-editor?.height or @.state.transformation-editor-height
            presentation-editor-height: ui?.presentation-editor?.height or @.state.presentation-editor-height
        }

    document-from-state: ->
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
        } = @.state
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
        {branch-id, query-id}? = @.props.params

        $ window .on \resize, ~> @.update-presentation-size!
        @.update-presentation-size!

        # TODO: fix Router.HistoryLocation & run the following code from both component-did-mount & component-will-receive-props methods
        load-document = (url) ~> $.getJSON url
            ..done (document) ~> @.set-state @.state-from-document document
        
        # :) if branch id & query id are present
        return load-document "/apis/queries/#{query-id}" if !!query-id and !(branch-id in <[local localFork]>)
        
        # redirect user to /branches/local/queries/:queryId if branchId is undefined
        if typeof branch-id == \undefined
            @.replace-with "/branches/local/queries/#{generate-uid!}"
            return load-document \/apis/defaultDocument

        throw "this case must be handled by express router" if !(branch-id in <[local localFork]>)

        # try to fetch the document from local-storage on failure we make an api call to get the default-document
        local-document = client-storage.get-document query-id
        return load-document \/apis/defaultDocument if (typeof local-document == \undefined) or local-document == null

        @.set-state @.state-from-document local-document

    update-presentation-size: ->
        left = @.state.editor-width + 10
        @.refs.presentation.get-DOM-node!.style <<< {
            left
            width: window.inner-width - left
            height: window.inner-height - @.refs.menu.get-DOM-node!.offset-height
        }

}