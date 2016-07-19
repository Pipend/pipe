require! \../lib/client-storage.ls
require! \../../config.ls
window.d3 = require \d3
$ = require \jquery-browserify
{key} = require \keymaster
require! \notifyjs

# prelude
{
    all, any, camelize, concat-map, dasherize, difference, each, filter, find, keys, is-type, last,
    map, sort, sort-by, sum, round, obj-to-pairs, pairs-to-obj, reject, take, unique, unique-by, Obj
} = require \prelude-ls

require! \base62
generate-uid = -> base62.encode Date.now!

{is-equal-to-object} = require \prelude-extension

# utils
{cancel-event, get-all-keys-recursively} = require \../lib/utils.ls

_ = require \underscore
{clone-element, create-class, create-factory, DOM}:React = require \react
{a, div, input, label, span, select, option, button, script} = DOM
{find-DOM-node}:ReactDOM = require \react-dom
require! \react-router
Link = create-factory react-router.Link
AceEditor = create-factory require \./AceEditor.ls
ConflictDialog = create-factory require \./ConflictDialog.ls
DataSourceCuePopup = create-factory require \./DataSourceCuePopup.ls
DocumentSearch = create-factory require \./DocumentSearch.ls
Menu = create-factory require \./Menu.ls
MultiSelect = create-factory (require \react-selectize).MultiSelect
NewQueryDialog = create-factory (require \./NewQueryDialog.ls)
ResizeableEditorGroup = create-factory (require \./ResizeableEditorGroup.ls)
SettingsDialog = create-factory require \./SettingsDialog.ls
SharePopup = create-factory require \./SharePopup.ls
StatusBar = create-factory require \./StatusBar.ls
VerticalNav = create-factory require \./VerticalNav.ls
VerticalSplitPane = create-factory require \./VerticalSplitPane.ls
ui-protocol =
    mongodb: require \../query-types/mongodb/ui-protocol.ls
    mssql: require \../query-types/mssql/ui-protocol.ls
    multi: require \../query-types/multi/ui-protocol.ls
    curl: require \../query-types/curl/ui-protocol.ls
    postgresql: require \../query-types/postgresql/ui-protocol.ls
    mysql: require \../query-types/mysql/ui-protocol.ls
    redis: require \../query-types/redis/ui-protocol.ls
    elastic: require \../query-types/elastic/ui-protocol.ls

pipe-web-client = (require \pipe-web-client) window.location.origin

UnAuthenticatedDialog = require \./auth/UnAuthenticatedDialog.ls
UnAuthorizedDialog = require \./auth/UnAuthorizedDialog.ls

alphabet = [String.from-char-code i for i in [65 to 65+25] ++ [97 to 97+25]]

Dialog = ({component, on-close}) ->

    header = div null, if !!on-close
        then 
            button do
                on-click: on-close
                "Close"
        else
            ""

    div do 
        class-name: 'dialog'
        div do
            class-name: 'dialog-wrapper'
            header
            component

DialogBox = require \./utils/Dialog.ls

# TODO: move it to utils
# takes a collection of keyscores & maps them to {name, value, score, meta}
# [{keywords: [String], score: Int}] -> String -> String -> [{name, value, score, meta}]
convert-to-ace-keywords = (keyscores, meta, prefix) ->
    keyscores |> concat-map ({keywords, score}) -> 
        keywords 
        |> filter (-> if !prefix then true else  (it.index-of prefix) == 0)
        |> map (text) ->
            name: text
            value: text
            meta: meta
            score: score

# returns dasherized collection of keywords for auto-completion
keywords-from-object = (object) ->
    object
        |> keys 
        |> map dasherize

# gracefully degrades if blocked by a popup blocker
# open-window :: URL -> Void
open-window = (url, target) !->
    if !window.open url, target
        alert "PLEASE DISABLE THE POPUP BLOCKER \n\nUNABLE TO OPEN: #{url}"

# to-callback :: p a -> (a -> b) -> Void
to-callback = (promise, callback) !->
    promise
    .then (result) -> callback null, result
    .catch (err) -> callback err, null

module.exports = create-class do

    display-name: \DocumentRoute

    # React class method
    # get-default-props :: a -> Props
    get-default-props: ->
        auto-execute: false
        prevent-reload: true

    # React class method
    # render :: a -> VirtualDOM
    render: ->
        {

            # --- document ---
            title
            data-source-cue
            transpilation-language
            query 
            transformation
            presentation
            parameters
            editor-width

            # --- ui ----
            cache
            dialog

            # --- save document ---
            versions-ahead
            remote-document

            # --- execution ---
            task-id
            displayed-on
            execution-error
            from-cache
            execution-end-time
            execution-duration

        } = @state

        menu-height = 50
        nav-width = 40
        status-bar-height = 24


        /*
        Editor :: {
            name :: String
            render-title :: () -> ReactElement
            content :: String
            height :: Int
            show-title :: Boolean
            show-content :: Boolean
            ace-editor-props :: {
                mode :: String
                theme :: String
                on-click :: () -> ()
            }
        }
        */
        # :: [Editor]
        editors =
            *   name: \query
                
                render-title: ->
                    span null, \Query

                ace-editor-props: 
                    on-click: ({dom-event:{meta-key}, editor}) ~>
                        if meta-key
                            {row, column} = editor.get-cursor-position!
                            session = editor.get-session!
                            current-token = session.get-token-at row, column
                            previous-token = (session.get-tokens row)[current-token.index - 2]
                            if \run-latest-query == (dasherize previous-token?.value ? "")
                                document-id = current-token.value.replace /\\|\"|\'/g, ""
                                open-window "/projects/#{@props.params.project-id}/documents/#{document-id}"

            *   name: \transformation
                render-title: -> 
                    span null, \Transformation

            *   name: \presentation
                render-title: -> 
                    div null,
                        div null, \Presentation
                        div class-name: \settings

        # get-editor-settings :: String -> object
        get-editor-settings = (name) ~>
            (ui-protocol[@state.data-source-cue.query-type]?["#{name}EditorSettings"] ? (->)) @state.transpilation-language

        time-formatter = d3.time.format "%d %b %I:%M %p"

        div class-name: \document-route,

            # MENU
            @render-menu!

            # DIALOGS
            @render-dialogs!

            div do 
                style: 
                    position: \relative

                # LEFT VERTICAL NAV
                VerticalNav do 
                    height: window.inner-height - menu-height
                    tabs: 
                        *   title: \Documents
                            component: DocumentSearch project-id: @props.params.project-id
                        ...
                    active-tab-title: @state.left-nav-active-tab-title

                    # on-active-tab-title-change :: String? -> ()
                    on-active-tab-title-change: (tab-title) !~>
                        @set-state left-nav-active-tab-title: tab-title
                
                # EDITORS & PRESENTATION
                VerticalSplitPane do 
                    style: do ~>
                        left = switch 
                            | typeof @state.left-nav-active-tab-title == \undefined => nav-width
                            | _ => nav-width + 250
                        left: left
                        width: window.inner-width - (nav-width + left)
                        height: window.inner-height - menu-height

                    # width of the ResizeableEditorGroup below
                    width-of-first-child: @state.editor-width
                    
                    # on-width-of-first-child-change :: Int -> ()
                    on-width-of-first-child-change: (new-width) !~>
                        @set-state editor-width: new-width

                    # EDITORS
                    ResizeableEditorGroup do
                        on-content-change: (content) ~>
                            <~ @set-state content
                            @save-to-client-storage-debounced!

                        on-height-change: @set-state.bind @
                        editors: editors 
                            |> filter ({name}) -> (get-editor-settings name).show-content
                            |> map ({name}:editor?) ~>

                                # editor props from ui-protocol
                                {
                                    show-title
                                    show-content
                                    ace-editor-props
                                } = get-editor-settings name
                                
                                {} <<< editor <<<
                                    content: @state[name]
                                    height: @state[camelize "#{name}EditorHeight"]
                                    show-title: show-title
                                    show-content: show-content
                                    ace-editor-props: {} <<< ace-editor-props <<< editor.ace-editor-props
                        
                    # PRESENTATION CONTAINER
                    div do
                        ref: camelize \presentation-container
                        class-name: "presentation-container #{if !!task-id then 'executing' else ''}"

                        # PRESENTATION: operations on this div are not controlled by react
                        div do 
                            ref: \presentation
                            class-name: \presentation
                            id: \presentation

                        # STATUS BAR
                        StatusBar do 
                            statuses:
                                *   title: 'Displayed on'
                                    value: time-formatter new Date displayed-on
                                    show: displayed-on

                                *   title: 'From Cache'
                                    value: if @props.from-cache then \Yes else \No
                                    show: displayed-on and !execution-error

                                *   title: 'Cached on'
                                    value: time-formatter new Date execution-end-time
                                    show: displayed-on and from-cache and !execution-error 

                                *   title: 'Execution time'
                                    value: "#{execution-duration / 1000} seconds"
                                    show: displayed-on and !execution-error
                            buttons: 
                                *   title: 'Task Manager'
                                    href: \/tasks
                                ...
    
                # RIGHT VERTICAL NAV
                VerticalNav do 
                    direction: \right
                    height: window.inner-height - menu-height - status-bar-height
                    style:
                        top: 0
                        right: 0
                        z-index: 2
                    tabs: 
                        *   title: 'Data Source'
                            component: div do 
                                null
                                # DATASOURCE POPUP
                                DataSourceCuePopup do
                                    data-source-cue: @state.data-source-cue
                                    project-id: @props.params.project-id
                                    left: -> 0
                                    on-change: (data-source-cue) ~> @set-state data-source-cue: {} <<< data-source-cue <<< complete: true


                        *   title: \Parameters
                            component: AceEditor do
                                editor-id: \parameters-editor
                                value: @state.parameters
                                on-change: (value) ~> 
                                    <~ @set-state parameters: value
                                    @save-to-client-storage-debounced!

    # render-menu :: () -> ReactElement
    render-menu: ->
        {

            # --- document ---
            data-source-cue
            remote-document
            transpilation-language

            # --- ui ----
            cache
            dialog

            # --- execution ---
            task-id

        } = @state

        # get the document-id & version from url via props.params
        document-id = @props.params.document-id
        version = 
            | typeof @props.params?.version == \string => parse-int version
            | _ => undefined

        saved-document = document-id and version > 0

        /* 
        MenuItem :: {
            type :: String
            label :: String
            hotkey :: String
            action :: a -> Void
            enabled :: Boolean
            highlight :: Boolean
            pressed :: Boolean
        } 
        */
        # :: [MenuItem]
        items-left = 

            *   label: \New
                href: "/projects/#{@props.params.project-id}/documents/new"

            *   label: \Save
                hotkey: "command + s"
                action: ~> @save!

            *   label: \Reset
                enabled: saved-document
                action: ~> 
                    <~ @set-state (@state-from-document remote-document)
                    @save-to-client-storage!
            
            *   label: \Clone
                action: ~> 
                    {version, parent-id, tree-id, title}:document? = @document-from-state!

                    # create a new copy of the document, update as required then save it to local storage
                    {version, document-id}:forked-document = {} <<< document <<< {
                        version: 0 #generate-uid!
                        parent-id: null
                        document-id: \local
                        tree-id: null
                        title: "Clone of #{title}"
                    }
                    client-storage.save-document document.project-id, document-id, version, forked-document

                    # by redirecting the user to a localFork branch we cause the document to be loaded from local-storage
                    open-window "/projects/#{@props.params.project-id}/documents/#{document-id}/versions/#{version}", \_blank

            * label: \Run
              enabled: data-source-cue.complete
              hotkey: "command + enter, control + enter"
              action: ~> @execute!

            * label: \Cache
              highlight: if @state.from-cache then 'rgba(0,255,0,1)' else null
              toggled: @state.cache
              type: \toggle
              action: ~> @set-state {cache: !@state.cache}

            # * label: \Cancel
            #   show: !!task-id
            #   action: ~> $.get "/apis/ops/#{task-id}/cancel"

            # * label: \Dispose
            #   show: !!@state.dispose
            #   action: ~> 
            #     @state.dispose!
            #     @set-state dispose: undefined

            ...

        Menu do 
            ref: \menu
            items-left: items-left |> filter ({show}) -> 
                (typeof show == \undefined) or show

            items-right: 
                * label: \Title
                  text: if @state.title and @state.title.length > 0 then @state.title else 'Untitled'
                  type: \textbox
                  action: (title) ~> @set-state {title}

                * label: \Settings
                  action: ~> @set-state {dialog: \settings} 
                
                * label: \History
                  enabled: saved-document
                  action: (->)
                
                * label: \Share
                  enabled: saved-document
                  action: ~> @set-state {dialog: \share-popup}

                * label: \Capture
                  enabled:saved-document
                  action: ~>
                      @save!.then ({document-id, version}) ~>
                          $.get "/apis/branches/#{document-id}/queries/#{version}/export/#{@state.cache}/png/1200/800?snapshot=true"

    # render-dialogs :: () -> ReactElement
    render-dialogs: ->

        # DIALOGS
        console.log \state.dialog, @state.dialog
        if !!@state.dialog
            div class-name: \dialog-container,
                match @state.dialog 

                | \share-popup =>
                    {parameters, transpilation} = @document-from-state!
                    [err, compiled-parameters] = pipe-web-client @props.params.project-id .compile-parameters-sync parameters, transpilation.query
                    DialogBox do
                        class-name: 'settings-dialog'
                        title: 'Settings'
                        cancel-label: 'Close'
                        on-cancel: ~> @set-state {dialog: null}
                        component: SharePopup do 
                            host: window.location.host
                            document-id: @state.document-id
                            project-id: @props.params.project-id
                            version: @state.version
                            compiled-parameters: compiled-parameters
                            data-source-cue: @state.data-source-cue


                | \new-query => 
                    NewQueryDialog do 
                        initial-data-source-cue: @state.data-source-cue
                        initial-transpilation-language: @state.transpilation-language
                        project-id: @props.params.project-id
                        on-create: (data-source-cue, transpilation-language) ~>
                            (pipe-web-client @props.params.project-id .load-default-document data-source-cue, transpilation-language)
                                .then (document) ~> 
                                    updated-document = {} <<< document <<< 
                                        document-id: @props.params.document-id
                                        version: parse-int @props.params.version
                                    # on-document-load expects local & remote document, 
                                    # in this case both local & remote will be the same documents
                                    @on-document-load updated-document, updated-document
                                .catch (err) ~> alert "Unable to get default document for: #{data-source-cue?.query-type}/#{transpilation-language} (#{err})"
                                .then ~> @set-state dialog: null

                | \save-conflict =>
                    ConflictDialog do 
                        versions-ahead: versions-ahead
                        on-cancel: ~> @set-state dialog: null, versions-ahead: null
                        on-resolution-select: (resolution) ~>
                            uid = generate-uid!
                            match resolution
                            | \new-commit => 
                                @save-document {} <<< @document-from-state! <<< {
                                    version: uid
                                    parent-id: versions-ahead.0
                                    document-id
                                    tree-id
                                }
                            | \fork => 
                                @save-document {} <<< @document-from-state! <<< {
                                    version: uid
                                    parent-id: version
                                    document-id: uid
                                    tree-id
                                }
                            | \reset => @set-state (@state-from-document remote-document)
                            @set-state dialog: null, versions-ahead: null

                | \settings => do ~>
                    callback = null

                    DialogBox do
                        class-name: 'settings-dialog'
                        title: 'Settings'
                        save-label: 'Save'
                        cancel-label: 'Cancel'
                        on-save: ~> callback ({urls, transpilation-language}) ~>
                            @load-client-external-libs urls, @state.client-external-libs
                            @set-state do
                                client-external-libs: urls
                                dialog: null
                                transpilation-language: transpilation-language

                        on-cancel: ~> @set-state dialog: null

                        component: do ~>
                            SettingsDialog do
                                initial-urls: @state.client-external-libs
                                initial-transpilation-language: @state.transpilation-language
                                get-state: (f) -> callback := f
                                on-change: ({urls, transpilation-language}) ~>
                                    @load-client-external-libs urls, @state.client-external-libs
                                    @set-state do
                                        client-external-libs: urls
                                        dialog: null
                                        transpilation-language: transpilation-language
                                    @save-to-client-storage-debounced!
                                on-cancel: ~> @set-state dialog: null

                | \error-unauthorized =>
                    UnAuthorizedDialog {}

                | \error-unauthenticated =>
                    UnAuthenticatedDialog {}

    # React class method
    # get-initial-state :: a -> UIState
    get-initial-state: ->
        cache: config?.cache-query ? true # user checked the cache checkbox
        dialog: null # String (name of the dialog to display)
        task-id: "" # String (alphanumeric task-id of the currently running query)
        from-cache: false # latest result is from-cache (it is returned by the server on execution)

        # DOCUMENT
        document-id: null
        version: null
        data-source-cue: config.default-data-source-cue
        title: "Untitled query"
        transpilation-language: config.default-transpilation-language
        query: ""
        transformation: ""
        presentation: ""
        parameters: ""
        client-external-libs: []
        editor-width: 550 
        tags: []
        keywords-from-query-result: []

        # UI DIMENSIONS
        left-nav-active-tab-title: undefined
        
    # on-document-load :: Document -> Document -> Void
    on-document-load: (local-document, remote-document) ->

        # existing-tags must also include tags saved on client storage 
        # existing-tags = (@state.existing-tags ? []) ++ ((local-document.tags ? []) |> map -> label: it, value: it)
        #     |> unique-by (.label)
        #     |> sort-by (.label)

        <~ @set-state {} <<< (@state-from-document local-document ? remote-document) <<< {remote-document}

        @save-to-client-storage!

        # create the auto-completer for ACE for the current data-source-cue
        # @setup-query-auto-completion!

        # now that we know the editor width, we should update the presentation size
        # @update-presentation-size!

        # redistribute the heights among the editors based on there visibility
        # @set-state editor-heights.apply do
        #     @
        #     <[query transformation presentation]> |> map ~>
        #         {show-content} = ui-protocol[@state.data-source-cue.query-type]?[camelize "#{it}-editor-settings"] @state.transpilation-language
        #         if !!show-content then @state[camelize "#{it}-editor-height"] else 0

        {cache, execute}? = @props.location.query

        # update cache checkbox from query-string
        <~ do ~> (callback) ~> 
            if typeof cache == \string
                @set-state do 
                    cache: cache == \true
                    callback
            else 
                callback!

        <~ to-callback (@load-client-external-libs @state.client-external-libs, [])

        # execute the query (if either config.auto-execute or query-string.execute is true)
        if @props.auto-execute or execute == \true
            @execute!

    # loads the document from local cache (if present) or server
    # invoked on page load or when the user changes the url
    # load :: Props -> Void
    load: (props) !->
        {project-id, document-id, version}? = props.params

        console.log \load-props-params=, props.params

        pwclient = pipe-web-client project-id

        if !!document-id 

            if typeof! version == \Undefined
                # handled by express, redirects the user to the latest version
                # eg: documents/:documentId
                throw  "not implemented at client level, (refresh the page)"

            version = parse-int version
            
            # local-document :: Document
            local-document = client-storage.get-document do
                project-id
                document-id
                parse-int version
            
            # :: (Promise p) => p Document -> (State changes)
            update-state-using-remote-document = (remote-document-p) !~>
                remote-document-p
                .then (remote-document) ~> @on-document-load local-document ? remote-document, remote-document
                .catch (error) ~> 
                    if error instanceof pwclient.Exceptions.UnAuthorizedException
                        @set-state {dialog: 'error-unauthorized'}
                    else if error instanceof pwclient.Exceptions.UnAuthenticatedException
                        @set-state {dialog: 'error-unauthenticated'}
                    else
                        console.error \update-state-using-remote-document, error
                    # alert err.to-string!
                    # window.location.href = \/
            
            # we are on local branch
            # eg: documents/local.../versions/0
            if (document-id.index-of \local) == 0
                
                # we are on a local branch and local-document exists
                # we can use the local-document.data-source-cue to get the default document to use it as remote document
                if local-document
                    {data-source-cue, transpilation-language}? = @state-from-document local-document
                    update-state-using-remote-document do 
                        pwclient.load-default-document do 
                            data-source-cue
                            transpilation-language

                # we are on a local branch and the local-document does not exist
                # this means its a new query, so we display the new query dialog
                else 
                    @set-state dialog: \new-query

            # load from local storage / remote
            # eg: documents/:documentId/versions/:version
            else
                update-state-using-remote-document do 
                    pwclient.load-document-version do 
                        document-id
                        version
        
        # document-id is not present in the url, redirect the user to new local document url
        else

            # this is the url used by 'New Query' button
            # it redirects user to documents/:documentId/versions/0 
            # eg: new/
            react-router.browser-history.replace do
                pathname: "/projects/#{project-id}/documents/local#{generate-uid!}/versions/0"
                query: {}
                state: null

    # React component life cycle method
    # component-did-mount :: a -> Void
    component-did-mount: !->

        # auto-completion for editors
        # transformation-keywords = ([{}, require \prelude-ls] |> concat-map keywords-from-object) ++ alphabet
        # presentation-keywords = ([{}, require \prelude-ls] |> concat-map keywords-from-object) ++ alphabet
        # d3-keywords = keywords-from-object d3
        # @default-completers =
        #     * get-completions: (editor, , , prefix, callback) ~>
        #         keywords-from-query-result = @state[camelize \keywords-from-query-result]
        #         range = editor.getSelectionRange!.clone!
        #             ..set-start range.start.row, 0
        #         text = editor.session.get-text-range range
        #         [keywords, meta] = match editor.container.id
        #             | \transformation-editor => [(unique <| transformation-keywords ++ keywords-from-query-result), \transformation]
        #             | \presentation-editor => [(unique <| if /.*d3\.($|[\w-]+)$/i.test text then d3-keywords else presentation-keywords), \presentation]
        #             | _ => [alphabet, editor.container.id]
        #         callback null, (convert-to-ace-keywords [keywords: keywords, score: 1], meta, prefix)
        #     ...
        # ace-language-tools.set-completers @default-completers

        # auto completion for tags
        # pipe-web-client.get-all-tags!.then (existing-tags) ~>
        #     @set-state do 
        #         existing-tags: ((@state.existing-tags ? []) ++ (existing-tags |> map -> label: it, value: it))
        #             |> unique-by (.label)
        #             |> sort-by (.label)

        # create a debounced version of save-to-local-storage
        @save-to-client-storage-debounced = _.debounce @save-to-client-storage, 350

        # crash recovery
        @unload-listener = (e) ~> 
            @save-to-client-storage!

            unsaved-changes = 
                | @changes-made!.length > 0 =>
                    @save-to-client-storage!
                    true
                | _ => false

            if config.prevent-reload and unsaved-changes
                message = "You have NOT saved your query. Stop and save if your want to keep your query."
                (e || window.event)?.return-value = message
                message
        
        window.add-event-listener \beforeunload, @unload-listener

        # update the size of the presentation on resize (based on size of editors)
        # $ window .on \resize, ~> @update-presentation-size!
        # @update-presentation-size!
        
        # request permission for push notifications
        if notifyjs.needs-permission
            notifyjs.request-permission!

        # selects presentation content only
        key 'command + a', (e) ~> 
            if e.target == document.body
                range = document.create-range!
                    ..select-node-contents find-DOM-node @refs.presentation
                selection = window.get-selection!
                    ..remove-all-ranges!
                    ..add-range range
                cancel-event e

            else
                true

        # load the document based on the url
        @load @props

    # # React component life cycle method (invoked before props are set)
    # # component-will-receive-props :: Props -> Void
    component-will-receive-props: (props) !->
        
        console.log \component-will-receive-props, props

        # return if branch & query id did not change
        return if props.params.document-id == @props.params.document-id and props.params.version == @props.params.version

        # return if the document with the new changes to props is already loaded
        # after saving the document we update the url (this prevents reloading the saved document from the server)
        return if props.params.document-id == @state.document-id and props.params.version == @state.version

        @load props

    # # React component life cycle method (invoked after the render function)
    # # updates the list of auto-completers if the data-source-cue has changed
    # # component-did-update :: Props -> State -> Void
    # component-did-update: (prev-props, prev-state) !->

    #     # call on-query-changed method, returned when setting up the auto-completer
    #     # this method uses the query to build the AST which is used internally to 
    #     # create the get-completions method for AceEditor
    #     do ~>
    #         if !!@on-query-changed-p and @state.query != prev-state.query
    #             @on-query-changed-p.then ~> it @state.query
        
    #     # auto-complete
    #     do ~>
    #         {data-source-cue, transpilation-language} = @state

    #         # return if the data-source-cue is not complete or there is no change in the data-source-cue
    #         if (data-source-cue.complete and !(data-source-cue `is-equal-to-object` prev-state.data-source-cue)) or transpilation-language != prev-state.transpilation-language
    #             @setup-query-auto-completion!

    #             # redistribute the heights among the editors based on there visibility
    #             @set-state editor-heights.apply do 
    #                 @
    #                 <[query transformation presentation]> |> map ~>
    #                     {show-content} = ui-protocol[@state.data-source-cue.query-type]?[camelize "#{it}-editor-settings"] @state.transpilation-language
    #                     if !!show-content then @state[camelize "#{it}-editor-height"] else 0

    # React component life cycle method
    # component-will-unmount :: a -> Void
    component-will-unmount: ->
        if @unload-listener
            window.remove-event-listener \beforeunload, @unload-listener

    # load-client-external-libs :: [String] -> [String] -> p a
    load-client-external-libs: (next, prev) ->

        # remove urls from head
        (prev `difference` next) |> each ~>
            switch (last url.split \.)
            | \js => $ "head > script[src='#{url}'" .remove!
            | \css => $ "head > link[href='#{url}'" .remove!

        # add urls to head
        urls-to-add = next `difference` prev

        if urls-to-add.length > 0
            (pipe-web-client @props.params.project-id) .require-deps next

        else 
            new Promise (res) ~> res \done

    # # SIDEEFFECT
    # # uses @state.data-source-cue, @state.transpilation-language
    # # adds @on-query-changed-p :: p (String -> p AST)
    # # setup-query-auto-completion :: a -> Void
    # setup-query-auto-completion: !->
    #     {data-source-cue, query, transpilation-language} = @state
    #     {query-type} = data-source-cue
    #     {make-auto-completer} = ui-protocol[query-type]

    #     # set the default completers (removing the currently set query completer if any)
    #     ace-language-tools.set-completers @default-completers

    #     # @on-query-changed-p :: p (String -> p AST)
    #     @on-query-changed-p = make-auto-completer (.container.id == \query-editor), [data-source-cue, transpilation-language] .then ({get-completions, on-query-changed}) ~>
    #         ace-language-tools.set-completers [{get-completions}] ++ @default-completers
    #         on-query-changed query
    #         on-query-changed    

    # execute :: a -> Void
    execute: !->

        if @state.task-id
            return

        {
            title
            data-source-cue
            query
            transformation
            presentation
            parameters
            transpilation
        }:document-from-state = @document-from-state!
        
        {
            compile-parameters
            compile-transformation
            compile-presentation
            execute
        } = pipe-web-client @props.params.project-id

        compiled-parameters <~ compile-parameters parameters, transpilation.query .then _

        # process-query-result :: Result -> p (a -> Void)
        # used only once
        process-query-result = (result) ~>
            transformation-function <~ compile-transformation transformation, transpilation.transformation .then _
            presentation-function <~ compile-presentation presentation, transpilation.presentation .then _
            
            # execute the transformation code
            try
                transformed-result = transformation-function result, compiled-parameters
            catch ex
                return new Promise (, rej) -> rej "ERROR IN THE TRANSFORMATION EXECUTAION: #{ex.to-string!}"

            view = find-DOM-node @refs.presentation

            # if transformation returns a RxJS stream then listen to it and update the presentation
            if \Function == typeof! transformed-result.subscribe
                subscription = transformed-result.subscribe (e) -> presentation-function view, e, compiled-parameters
                Promise.resolve -> subscription.dispose!

            # otherwise invoke the presentation function once with the JSON returned from transformation
            else
                try
                    presentation-function view, transformed-result, compiled-parameters
                catch ex
                    return new Promise (, rej) -> rej "ERROR IN THE PRESENTATION EXECUTAION: #{ex.to-string!}"
                Promise.resolve null
        
        # dispose the result of any previous execution
        <~ do ~> (callback) ~>
            if @state.dispose
                @state.dispose!
                @set-state {dispose: undefined}, callback
            else
                callback!

        # update the ui to reflect that an task is going to start
        # task-id is used to remember if  there is on going query
        <~ @set-state task-id: "#{Date.now! * 1000 + Math.floor (Math.random! * 9999)}"

        err, {dispose, result-with-metadata}? <~ to-callback do ~>

            # clean existing presentation
            ($ find-DOM-node @refs.presentation).empty!

            # make the ajax request and process the query result
            {result}:result-with-metadata <~ (execute do
                @state.task-id
                {}
                @props.params.document-id
                @props.params.version
                data-source-cue
                query
                transpilation.query
                compiled-parameters
                @state.cache) .then

            # transform and visualize the result
            dispose <~ process-query-result result .then
            Promise.resolve {dispose, result-with-metadata}

        # update the ui to reflect that the task is complete
        <~ @set-state displayed-on: Date.now!, task-id: "" 

        if err
            pre = $ "<pre/>"
                ..html err.to-string!
            ($ find-DOM-node @refs.presentation).append pre
            @set-state execution-error: true

        else

            {result, from-cache, execution-end-time, execution-duration} = result-with-metadata

            # extract keywords from query result (for autocompletion in transformation)
            # keywords-from-query-result = switch
            #     | is-type 'Array', result => result ? [] |> take 10 |> get-all-keys-recursively (-> true) |> unique
            #     | is-type 'Object', result => get-all-keys-recursively (-> true), result
            #     | _ => []

            # update the status bar below the presentation            
            <~ @set-state {from-cache, execution-end-time, execution-duration, dispose}

            # notify the user
            if document.webkit-hidden
                notification = new notifyjs do 
                    'Pipe: query execution complete'
                    body: "Completed execution of (#{@state.title}) in #{@state.execution-duration / 1000} seconds"
                    notify-click: -> window.focus!
                notification.show!

    # returns a list of document properties (from current UIState) that diverged from the remote document
    # changes-made :: a -> [String]
    changes-made: ->

        if @state.remote-document
            unsaved-document = @document-from-state!
            <[title dataSourceCue query transformation presentation parameters transpilation]>
                |> filter ~> !(unsaved-document?[it] `is-equal-to-object` @state.remote-document?[it])

        # there are no changes made if the query does not exist on the server 
        else
            []

    # converts the current UIState to Document & POST's it as a "save" request to the server
    # save :: (Promise p) => a -> p Document
    save: ->
        if @changes-made!.length == 0
            Promise.resolve @document-from-state!
        else 
            @save-document @document-from-state!

    # save-document :: (Promise p) => Document -> p Document
    save-document: (document-to-save) ->
        {project-id} = @props.params
        
        (pipe-web-client project-id .save-document document-to-save)
            .then ({project-id, document-id, version}:saved-document) ~>

                # update the local storage with the saved document
                client-storage.delete-document do 
                    @props.params.project-id
                    @props.params.document-id
                    @props.params.version

                # update the state with saved-document
                @set-state {} <<< (@state-from-document saved-document) <<< remote-document: saved-document

                # update the url to point to the latest query id
                react-router.browser-history.replace do 
                    pathname: "/projects/#{project-id}/documents/#{document-id}/versions/#{version}"
                    query: {}
                    state: saved-document

                saved-document

            .catch (err) ~>
                if (err?.length ? 0) > 0
                    @set-state dialog: \save-conflict, versions-ahead: err
                
                else
                    throw err

    # save to client storage only if the document has loaded
    # save-to-client-storage :: a -> Void
    save-to-client-storage: !-> 
        if @state.remote-document
            {project-id, document-id, version} = @props.params
            client-storage.save-document do 
                project-id
                document-id
                parse-int version
                @document-from-state!
    
    # converting the document to a flat object makes it easy to work with 
    # state-from-document :: Document -> UIState
    state-from-document: ({
        document-id
        version
        data-source-cue
        title
        query
        transformation
        presentation
        parameters
        transpilation
        client-external-libs
        ui
    }?) ->
        {
            document-id
            version
            data-source-cue
            title
            query
            transformation
            presentation
            parameters
            transpilation-language: transpilation?.query ? \livescript
            client-external-libs: client-external-libs ? []
            # editor-width: ui?.editor?.width or @state.editor-width
        } 
        # <<< editor-heights do 
        #     ui?.query-editor?.height or @state.query-editor-height
        #     ui?.transformation-editor?.height or @state.transformation-editor-height
        #     ui?.presentation-editor?.height or @state.presentation-editor-height

    # document-from-state :: a -> Document
    document-from-state: ->
        {
            document-id
            version
            data-source-cue
            title
            query
            transformation
            presentation
            parameters
            transpilation-language
            client-external-libs
            editor-width
            query-editor-height
            transformation-editor-height
            presentation-editor-height
        } = @state

        {
            document-id
            version
            data-source-cue
            title
            transpilation:
                query: transpilation-language
                transformation: transpilation-language
                presentation: transpilation-language
            query
            transformation
            presentation
            parameters
            client-external-libs
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