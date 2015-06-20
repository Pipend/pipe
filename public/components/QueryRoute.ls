AceEditor = require \./AceEditor.ls
DataSourcePopup = require \./DataSourcePopup.ls
{default-type} = require \../../config.ls
Menu = require \./Menu.ls
{any, camelize, concat-map, dasherize, filter, find, keys, last, map, sum, round, obj-to-pairs, pairs-to-obj, unique, take} = require \prelude-ls
{DOM:{div, input, label, span}}:React = require \react
ui-protocol =
    mongodb: require \../query-types/mongodb/ui-protocol.ls
    mssql: require \../query-types/mssql/ui-protocol.ls
    multi: require \../query-types/multi/ui-protocol.ls
    curl: require \../query-types/curl/ui-protocol.ls
$ = require \jquery-browserify
window.d3 = require \d3-browserify
{compile-and-execute-livescript, generate-uid, is-equal-to-object, get-all-keys-recursively} = require \../utils.ls
transformation-context = require \../transformation/context.ls
presentation-context = require \../presentation/context.ls
SharePopup = require \./SharePopup.ls
{Navigation} = require \react-router
client-storage = require \../client-storage.ls
ConflictDialog = require \./ConflictDialog.ls
_ = require \underscore
ace-language-tools = require \brace/ext/language_tools 
notify = require \notifyjs

# returns dasherized collection of keywords for auto-completion
keywords-from-object = (object) ->
    object
        |> keys 
        |> map dasherize

# takes a collection of keywords & maps them to {name, value, score, meta}
convert-to-ace-keywords = (keywords, meta, prefix) ->
    keywords
        |> map -> {text: it, meta}
        |> filter -> (it.text.index-of prefix) == 0 
        |> map ({text, meta}) -> {name: text, value: text, score: 0, meta}

alphabet = [String.from-char-code i for i in [65 to 65+25] ++ [97 to 97+25]]

module.exports = React.create-class do

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
            cache
            from-cache
            executing-op
            displayed-on
            execution-error
            execution-end-time
            execution-duration
        } = @.state

        # MENU ITEMS
        toggle-popup = (button-left, popup-name) ~> @.set-state do
            popup-left: button-left - 100
            popup: if @.state.popup == popup-name then '' else popup-name

        saved-query = !!@.props.params.branch-id and !(@.props.params.branch-id in <[local localFork]>) and !!@.props.params.query-id

        menu-items = 
            * icon: \n, label: \New, action: ~> window.open "/branches", \_blank
            * icon: \f, label: \Fork, show: saved-query, action: ~> @.fork!
            * hotkey: "command + s", icon: \s, label: \Save, action: ~> @.save!            
            * type: \toggle
              icon: \c
              label: \Cache
              highlight: if from-cache then 'rgba(0,255,0,1)' else null
              toggled: cache
              action: ~> @.set-state {cache: !cache}
            * hotkey: "command + enter"
              icon: \e
              label: \Execute
              show: !executing-op
              action: ~> @.set-state {executing-op: @.execute!}
            * icon: \ca
              label: \Cancel
              show: !!executing-op
              action: ~> 
                  $.get "/apis/ops/#{executing-op}/cancel"
                      ..done ~> @.set-state {executing-op: 0}
            * icon: \d, label: 'Data Source', action: (button-left) ~> toggle-popup button-left, \data-source-popup
            * icon: \p, label: \Parameters, action: (button-left) ~> toggle-popup button-left, \parameters-popup
            * icon: \t, label: \Tags, action: ~>
            * icon: \r, label: \Reset, show: saved-query, action: ~> @.set-state remote-document
            * icon: \t
              label: \Diff
              show: saved-query
              highlight: do ~>
                changes = @.changes-made!
                return null if changes.length == 0
                return 'rgba(0,255,0,1)' if changes.length == 1 and changes.0 == \parameters
                'rgba(255,255,0,1)'
              action: ~> window.open "#{window.location.href}/diff", \_blank
            * icon: \h, label: \Share, show: saved-query, action: (button-left) ~> toggle-popup button-left, \share-popup
            * icon: \s, label: \Snapshot, show:saved-query, action: @.save-snapshot
            
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
                    on-change: (data-source) ~> 
                        <~ @.set-state {data-source}
                        @.save-to-client-storage-debounced!

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
                            resizable: true
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
                                        initial-heights = ["transformation", "presentation", "query"]
                                            |> map (p) ~> [p, @.state[camelize "#{p}-editor-height"]]
                                            |> pairs-to-obj
                                        $ window .on \mousemove, ({pageY}) ~> 
                                            diff = pageY - initialY
                                            match editor-id 
                                                | "query" =>
                                                    transformation-editor-height = initial-heights.transformation - diff
                                                    query-editor-height = initial-heights.query + diff
                                                    if transformation-editor-height > 0 and query-editor-height > 0
                                                        @.set-state {transformation-editor-height, query-editor-height}
                                                | "transformation" =>
                                                    transformation-editor-height = initial-heights.transformation + diff
                                                    presentation-editor-height = initial-heights.presentation - diff
                                                    if transformation-editor-height > 0 and presentation-editor-height > 0
                                                        @.set-state {transformation-editor-height, presentation-editor-height}
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
                
                div {
                    ref: camelize \presentation-container
                    class-name: "presentation-container #{if !!executing-op then 'executing' else ''}"
                },

                    # PRESENTATION: operations on this div are not controlled by react
                    div {ref: \presentation, class-name: \presentation}

                    # STATUS BAR
                    if !!displayed-on
                        time-formatter = d3.time.format("%d %b %I:%M %p")
                        items = 
                            * title: 'Displayed on'
                              value: time-formatter new Date displayed-on
                            * title: 'From cache'
                              value: if from-cache then \Yes else \No
                              show: !execution-error
                            * title: 'Cached on'
                              value: time-formatter new Date execution-end-time
                              show: !execution-error and from-cache
                            * title: 'Execution time'
                              value: "#{execution-duration / 1000} seconds"
                              show: !execution-error
                        div {class-name: \status-bar},
                            items 
                                |> filter -> (typeof it.show == \undefined) or !!it.show
                                |> map ({title, value}) ->
                                    div null,
                                        label null, title
                                        span null, value
        
    update-presentation-size: ->
        left = @.state.editor-width + 10
        @.refs.presentation-container.get-DOM-node!.style <<< {
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

    # execute :: () -> String
    execute: ->
        {
            data-source
            query
            transformation
            presentation
            parameters
            cache
            executing-op
        } = @.state

        return executing-op if !!executing-op        

        display-error = (err) !~>
            pre = $ "<pre/>"
            pre.html err.to-string!
            $ @.refs.presentation.get-DOM-node! .empty! .append pre
            @.set-state {from-cache: false, execution-error: true}

        op-id = generate-uid!
        $.ajax {
            type: \post
            url: \/apis/execute
            content-type: 'application/json; charset=utf-8'
            data-type: \json
            data: JSON.stringify {op-id, document: @.document-from-state!, cache}
            success: ({result, from-cache, execution-end-time, execution-duration}) ~>

                keywords-from-query-result = result ? [] |> take 10 |> get-all-keys-recursively (-> true) |> unique

                # clean existing presentation
                $ @.refs.presentation.get-DOM-node! .empty!

                if !!parameters and parameters.trim!.length > 0
                    [err, parameters-object] = compile-and-execute-livescript parameters, {}
                    console.log err if !!err

                parameters-object ?= {}

                [err, func] = compile-and-execute-livescript "(#transformation\n)", {} <<< transformation-context! <<< parameters-object <<< (require \prelude-ls)
                return display-error "ERROR IN THE TRANSFORMATION COMPILATION: #{err}" if !!err
                
                try
                    transformed-result = func result
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

                <~ @.set-state {
                    from-cache
                    execution-end-time
                    execution-duration
                    keywords-from-query-result
                    execution-error: false
                }
                if document[\webkitHidden]
                    notification = new notify do 
                        'Pipe: query execution complete'
                        body: "Completed execution of (#{@.state.query-title}) in #{@.state.execution-duration / 1000} seconds"
                        notify-click: -> window.focus!
                    notification.show!

            error: ({response-text}?) ->
                display-error response-text

            complete: ~>
                @.set-state {displayed-on: Date.now!, executing-op: ""}                

        }
        op-id

    POST-document: (document-to-save, callback) ->
        $.ajax {
            type: \post
            url: \/apis/save
            content-type: 'application/json; charset=utf-8'
            data-type: \json
            data: JSON.stringify document-to-save
        }
            ..done ({query-id, branch-id}:saved-document) ~>
                client-storage.delete-document @.props.params.query-id
                @.set-state {} <<< saved-document <<< {remote-document: saved-document}
                @.transition-to "/branches/#{branch-id}/queries/#{query-id}"
                callback saved-document if !!callback
            ..fail ({response-text}:err?) ~>
                return alert 'SERVER ERROR' if !response-text
                try
                    {queries-in-between}? = JSON.parse response-text
                catch exception
                    return alert 'SERVER ERROR'
                return alert 'SERVER ERROR' if !queries-in-between
                @.set-state {dialog: \save-conflict, queries-in-between}
    
    changes-made: ->

        # there are no changes made if the query does not exist on the server 
        return [] if !@.state.remote-document

        unsaved-document = @.document-from-state!
        <[query transformation presentation parameters queryTitle dataSource]>
            |> filter ~> !(unsaved-document?[it] `is-equal-to-object` @.state.remote-document?[it])

    save: (callback) ->
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

        if @.changes-made!.length == 0
            callback @.document-from-state! if !!callback
            return

        uid = generate-uid! 
        {query-id, tree-id}:document = @.document-from-state!

        # a new query-id is generate at the time of save, parent-id is set to the old query-id
        # expect in the case of a forked-query (whose parent-id is saved in the local-storage at the time of fork)
        @.POST-document do 
            {} <<< document <<< {
                query-id: uid
                parent-id: switch @.props.params.branch-id
                    | \local => null
                    | \local-fork => parent-id
                    | _ => query-id
                branch-id: if (@.props.params.branch-id.index-of \local) == 0 then uid else @.props.params.branch-id
                tree-id: tree-id or uid
            }
            callback

    save-snapshot: ->
        {branch-id, query-id}:saved-document <~ @.save
        $.get "/apis/branches/#{branch-id}/queries/#{query-id}/export/#{@.state.cache}/png/320/240?snapshot=true"

    save-to-client-storage: -> client-storage.save-document @.props.params.query-id, @.document-from-state!

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
                ..fail ({response-text}?) ~> 
                    alert "unable to load query: #{response-text}"
                    window.location.href = \/

        # :) if branch id & query id are present
        return load-document query-id, "/apis/queries/#{query-id}" if !!query-id and !(branch-id in <[local localFork]>)            
        
        # redirect user to /branches/local/queries/:queryId if branchId is undefined
        return @.replace-with "/branches/local/queries/#{generate-uid!}" if typeof branch-id == \undefined

        throw "this case must be handled by express router" if !(branch-id in <[local localFork]>)

        # try to fetch the document from local-storage on failure we make an api call to get the default-document
        load-document query-id, \/apis/defaultDocument

    component-did-mount: ->

        # setup auto-completion
        transformation-keywords = ([transformation-context!, require \prelude-ls] |> concat-map keywords-from-object) ++ alphabet
        d3-keywords = keywords-from-object d3
        presentation-keywords = ([presentation-context!, require \prelude-ls] |> concat-map keywords-from-object) ++ alphabet
        @.default-completers =
            * protocol: 
                get-completions: (editor, , , prefix, callback) ~>
                    keywords-from-query-result = @.state[camelize \keywords-from-query-result]
                    range = editor.getSelectionRange!.clone!
                        ..set-start range.start.row, 0
                    text = editor.session.get-text-range range
                    [keywords, meta] = match editor.container.id
                        | \transformation-editor => [transformation-keywords ++ keywords-from-query-result, \transformation]
                        | \presentation-editor => [(if /.*d3\.($|[\w-]+)$/i.test text then d3-keywords else presentation-keywords), \presentation]
                        | _ => [alphabet, editor.container.id]
                    callback null, (convert-to-ace-keywords keywords, meta, prefix)
            ...
        ace-language-tools.set-completers (@.default-completers |> map (.protocol))

        # data loss prevent on crash
        @.save-to-client-storage-debounced = _.debounce @.save-to-client-storage, 350
        window.onbeforeunload = ~>
            @.save-to-client-storage!            
            return "You have NOT saved your query. Stop and save if your want to keep your query." if @.changes-made!.length > 0

        # update the size of the presentation on resize (based on size of editors)
        $ window .on \resize, ~> @.update-presentation-size!
        @.update-presentation-size!

        # load the document based on the url
        @.load @.props
        notify.request-permission! if notify.needs-permission

    component-will-receive-props: (props) ->
        # return if branch & query id did not change
        return if props.params.branch-id == @.props.params.branch-id and props.params.query-id == @.props.params.query-id

        # return if the document with the new changes to props is already loaded
        return if props.params.branch-id == @.state.branch-id and props.params.query-id == @.state.query-id

        @.load props    

    component-did-update: (prev-props, prev-state) ->
        {data-source} = @.state

        # return if there is no change in the data-source
        return if data-source `is-equal-to-object` prev-state.data-source
        
        # @.completers is an array that stores a completer for each data-source
        @.completers = [] if !@.completers

        # tries to find and return an exiting completer for the current data-source iff the completer has a protocol property
        existing-completer = @.completers |> find -> it.data-source `is-equal-to-object` data-source
        return ace-language-tools.set-completers [existing-completer.protocol] ++ (@.default-completers |> map (.protocol)) if !!existing-completer?.protocol
        
        completer = existing-completer or {data-source}

        # aborts any previous on-going requests for keywords before starting a new one
        # on success updates the protocol property of the completer
        @.keywords-request.abort! if !!@.keywords-request
        @.keywords-request = $.ajax do
            type: \post
            url: "/apis/queryTypes/#{@.state.data-source.type}/keywords"
            content-type: 'application/json; charset=utf-8'
            data-type: \json
            data: JSON.stringify data-source
            success: (keywords) ~>
                completer.protocol =
                    get-completions: (editor, , , prefix, callback) ->
                        range = editor.getSelectionRange!.clone!
                            ..set-start range.start.row, 0
                        text = editor.session.get-text-range range
                        if editor.container.id == \query-editor
                            callback null, (convert-to-ace-keywords keywords, data-source.type, prefix)    
                if data-source `is-equal-to-object` @.state.data-source
                    ace-language-tools.set-completers [completer.protocol] ++ (@.default-completers |> map (.protocol)) 

        # a completer may already exist (but without a protocol, likely because the keywords request was aborted before)
        @.completers.push completer if !existing-completer

    get-initial-state: ->
        viewport-height = window.inner-height - 50 - 3 * (40 + 5) # 50 = height of .menu defined in Meny.styl; 40 = height of .editor-title; 5 = height of resize-handle defined in QueryRoute.styl
        editor-heights = [300, 324, 240] |> (ds) ->
            s = sum ds
            ds |> map round . (viewport-height *) . (/s)
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
            query-editor-height: editor-heights.0
            transformation-editor-height: editor-heights.1
            presentation-editor-height: editor-heights.2
            dialog: false
            popup: null
            cache: true # user checked the cache checkbox
            from-cache: false # latest result is from-cache (it is returned by the server on execution)
            executing-op: 0
            keywords-from-query-result: []
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

