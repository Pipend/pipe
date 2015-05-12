AceEditor = require \./AceEditor.ls
DataSourcePopup = require \./DataSourcePopup.ls
{default-type} = require \../../config.ls
Menu = require \./Menu.ls
{any, camelize, filter, last, map} = require \prelude-ls
{DOM:{div, input}}:React = require \react
ui-protocol =
    mongodb: require \../query-types/mongodb/ui-protocol.ls
    mssql: require \../query-types/mssql/ui-protocol.ls
$ = require \jquery-browserify
window.d3 = require \d3-browserify
{compile-and-execute-livescript, generate-uid, is-equal-to-object} = require \../utils.ls
transformation-context = require \../transformation/context.ls
presentation-context = require \../presentation/context.ls
SharePopup = require \./SharePopup.ls
{Navigation} = require \react-router
client-storage = require \../client-storage.ls
ConflictDialog = require \./ConflictDialog.ls
_ = require \underscore

module.exports = React.create-class {

    display-name: \QueryRoute

    mixins: [Navigation]

    render: ->
        {
            query-id
            branch-id
            tree-id
            data-source
            query
            query-title
            transformation
            presentation
            parameters
            editor-width
            popup-left
            popup
            queries-in-between
            dialog
            remote-document
        } = @.state

        # MENU ITEMS
        toggle-popup = (button-left, popup-name) ~> @.set-state do
            popup-left: button-left - 100
            popup: if @.state.popup == popup-name then '' else popup-name

        saved-query = !!@.props.params.branch-id and !(@.props.params.branch-id in <[local localFork]>) and !!@.props.params.query-id

        menu-items = 
            * icon: \n, label: \New, action: ~> window.open "/branches", \_blank
            * icon: \f, label: \Fork, show: saved-query, action: @.fork
            * hotkey: "command + s", icon: \s, label: \Save, action: @.save
            * icon: \r, label: \Reset, show: saved-query, action: ~> @.set-state remote-document
            * icon: \c, label: \Cache, action: ~>
            * hotkey: "command + enter", icon: \e, label: \Execute, action: @.execute
            * icon: \d, label: 'Data Source', action: (button-left) ~> toggle-popup button-left, \data-source-popup
            * icon: \p, label: \Parameters, action: (button-left) ~> toggle-popup button-left, \parameters-popup
            * icon: \t, label: \Tags, action: ~>
            * icon: \t, label: \VCS, show: saved-query, action: ~>
            * icon: \h, label: \Share, show: saved-query, action: (button-left) ~> toggle-popup button-left, \share-popup

        div {class-name: \query-route},

            # MENU 
            React.create-element do 
                Menu
                ref: \menu
                items: menu-items |> filter ({show}) -> (typeof show == \undefined) or show

            # POPUPS 
            match popup
            | \data-source-popup =>
                React.create-element do
                    DataSourcePopup
                    left: popup-left
                    data-source: data-source
                    data-source-component: ui-protocol[data-source.type].data-source-component
                    on-change: (data-source) ~> @.set-state {data-source}

            | \parameters-popup =>
                div {class-name: 'parameters-popup popup', style: {left: popup-left}},
                    React.create-element AceEditor, do
                        editor-id: "parameters-editor"                            
                        value: @.state.parameters
                        width: 400
                        height: 300                            
                        on-change: (value) ~> 
                            <~ @.set-state {parameters : value}
                            @.save-to-client-storage-debounced!

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

            # DIALOGS
            if !!dialog
                div {class-name: \dialog-container},
                    match dialog
                    | \save-conflict =>
                        React.create-element do 
                            ConflictDialog
                            {
                                queries-in-between
                                on-cancel: ~> @.set-state {dialog: null, queries-in-between: null}
                                on-resolution-select: (resolution) ~>                                     
                                    uid = generate-uid!
                                    match resolution
                                    | \new-commit =>
                                        @.POST-document {} <<< @.document-from-state! <<< {
                                            query-id: uid
                                            parent-id: queries-in-between.0
                                            branch-id
                                            tree-id
                                        }
                                    | \fork =>                                        
                                        @.POST-document {} <<< @.document-from-state! <<< {
                                            query-id: uid
                                            parent-id: query-id
                                            branch-id: uid
                                            tree-id
                                        }
                                    | \reset => @.set-state remote-document                                    
                                    @.set-state {dialog: null, queries-in-between: null}
                            }

            div {class-name: \content},

                # EDITORS
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

                            # EDITABLE TITLE
                            div {class-name: \editor-title},
                                if editable-title 
                                    input do
                                        type: \text
                                        value: title or @.state["#{editor-id}Title"]
                                        on-change: ({current-target:{value}}) ~> 
                                            <~ @.set-state {"#{editor-id}Title" : value}
                                            @.save-to-client-storage-debounced!
                                else
                                    title

                            # ACE EDITOR
                            React.create-element AceEditor, {
                                editor-id: "#{editor-id}-editor"
                                value: @.state[editor-id]
                                height: @.state["#{editor-id}EditorHeight"]
                                on-change: (value) ~>
                                    <~ @.set-state {"#{editor-id}" : value}
                                    @.save-to-client-storage-debounced!
                            } <<< ui-protocol[data-source.type]?[camelize "get-#{editor-id}-editor-settings"]!
                            
                            # RESIZE HANDLE
                            if resizable 
                                div do
                                    class-name: \resize-handle
                                    on-mouse-down: (e) ~>
                                        initialY = e.pageY
                                        initial-height = @.state["#{editor-id}EditorHeight"]
                                        $ window .on \mousemove, ({pageY}) ~> @.set-state {"#{editor-id}EditorHeight": initial-height + (pageY - initialY)}
                                        $ window .on \mouseup, -> $ window .off \mousemove .off \mouseup

                # RESIZE HANDLE
                div do
                    class-name: \resize-handle
                    ref: \resize-handle
                    on-mouse-down: (e) ~>
                        initialX = e.pageX
                        initial-width = @.state.editor-width
                        $ window .on \mousemove, ({pageX}) ~> 
                            <~ @.set-state {editor-width: initial-width + (pageX - initialX)}
                            @.update-presentation-size!
                        $ window .on \mouseup, -> $ window .off \mousemove .off \mouseup
                
                # PRESENTATION: operations on this div are not controlled by react
                div {ref: \presentation, class-name: \presentation}
        
    update-presentation-size: ->
        left = @.state.editor-width + 10
        @.refs.presentation.get-DOM-node!.style <<< {
            left
            width: window.inner-width - left
            height: window.inner-height - @.refs.menu.get-DOM-node!.offset-height
        }

    fork: ->
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

    execute: ->
        {
            data-source
            query
            transformation
            presentation
            parameters
        } = @.state

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

    POST-document: (document-to-save) ->
        $.ajax {
            type: \post
            url: \/apis/save
            content-type: 'application/json; charset=utf-8'
            data-type: \json
            data: JSON.stringify document-to-save
        }
            ..done ({query-id, branch-id}:saved-document) ~>
                @.set-state {} <<< saved-document <<< {remote-document: saved-document}
                @.transition-to "/branches/#{branch-id}/queries/#{query-id}"
            ..fail ({response-text}:err?) ~>
                {queries-in-between}? = JSON.parse response-text
                @.set-state {dialog: \save-conflict, queries-in-between}
    
    has-document-changed: ->
        unsaved-document = @.document-from-state!
        <[query transformation presentation parameters queryTitle]>
            |> any ~> unsaved-document[it] != @.state.remote-document[it]

    save: ->
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
            popup
            queries-in-between
            dialog
        } = @.state

        # TODO: return if the document has not changed
        return if !@.has-document-changed!

        uid = generate-uid! 
        {query-id, tree-id}:document = @.document-from-state!

        # a new query-id is generate at the time of save, parent-id is set to the old query-id
        # expect in the case of a forked-query (whose parent-id is saved in the local-storage at the time of fork)
        @.POST-document {} <<< document <<< {
            query-id: uid
            parent-id: switch @.props.params.branch-id
                | \local => null
                | \local-fork => parent-id
                | _ => query-id
            branch-id: if (@.props.params.branch-id.index-of \local) == 0 then uid else @.props.params.branch-id
            tree-id: tree-id or uid
        }

    load: (props) ->
        {branch-id, query-id}? = props.params

        load-document = (query-id, url) ~> 
            local-document = client-storage.get-document query-id            
            $.getJSON url
                ..done (document) ~>
                    # gets the state from the document, and stores a copy of it under the key "remote-document"
                    # state.remote-document is used to check if the client copy has diverged
                    remote-document = @.state-from-document document
                    @.set-state {} <<< (local-document or remote-document) <<< {remote-document}
        
        # :) if branch id & query id are present
        return load-document query-id, "/apis/queries/#{query-id}" if !!query-id and !(branch-id in <[local localFork]>)            
        
        # redirect user to /branches/local/queries/:queryId if branchId is undefined
        return @.replace-with "/branches/local/queries/#{generate-uid!}" if typeof branch-id == \undefined

        throw "this case must be handled by express router" if !(branch-id in <[local localFork]>)

        # try to fetch the document from local-storage on failure we make an api call to get the default-document
        load-document query-id, \/apis/defaultDocument

    save-to-client-storage: -> client-storage.save-document @.props.params.query-id, @.document-from-state!

    component-did-mount: ->
        @.save-to-client-storage-debounced = _.debounce @.save-to-client-storage, 350
        window.onbeforeunload = ~>
            @.save-to-client-storage!            
            return "You have NOT saved your query. Stop and save if your want to keep your query." if @.has-document-changed!
        $ window .on \resize, ~> @.update-presentation-size!
        @.update-presentation-size!
        @.load @.props

    component-will-receive-props: (props) ->
        # return if branch & query id did not change
        return if props.params.branch-id == @.props.params.branch-id and props.params.query-id == @.props.params.query-id

        # return if the document with the new changes to props is already loaded
        return if props.params.branch-id == @.state.branch-id and props.params.query-id == @.state.query-id

        @.load props    

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
            dialog: false
            popup: null            
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

}