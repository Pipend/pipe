Clipboard = require \clipboard
{filter, find, fold, map, any, reject, sort-by, zip, take, drop} = require \prelude-ls
{create-class, create-factory, DOM:{button, div, h1, label, input, a, span, select, option}}:React = require \react
SimpleSelect = create-factory (require \react-selectize).SimpleSelect
SimpleButton = create-factory require \./SimpleButton.ls
{debounce} = require \underscore

LibrarySelect = create-factory create-class do 

    # get-default-props :: a -> Props
    get-default-props: ->
        id: ""
        url: ""
        ignore-urls: [] # [String]
        # on-change :: String -> Void
        on-change: ((url) !-> )

    # render :: a -> ReactElement
    render: ->
        url-regex = /^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$/

        SimpleSelect do
            class-name: @props.id
            ref: \select
            placeholder: "Select a library"
            options: @state.libraries
            value: if typeof @props.url == \undefined then undefined else latest: @props.url
            search: @state.search
            style: width: 800
            
            # create-from-search :: [Item] -> String -> Item
            create-from-search: (options, search) ~>
                return null if search.length == 0 or !(url-regex.test search) or (search in @props.ignore-urls)
                latest: search

            editable: (.latest)

            # on-search-change :: String -> (a -> Void) -> Void
            on-search-change: (search, callback) !~>
                @set-state {search}, callback
                if search.length > 0 and search != @props.url
                    @state.request.abort! if !!@state.request
                    request = $.getJSON "http://api.cdnjs.com/libraries?fields=version,homepage&search=#{search}"
                        ..done ({results}) ~>
                            @set-state do 
                                libraries: (results ? [])
                                    |> filter -> !!it.latest
                                    |> reject ~> it.latest in @props.ignore-urls
                                    |> take 50
                                ~> @refs.select.highlight-first-selectable-option!
                        ..always ~> @set-state request: undefined
                    @set-state {request}
            
            # on-value-change :: Item -> (a -> Void) -> Void
            on-value-change: ({latest}?, callback) !~>
                <~ @set-state libraries: []
                @props.on-change latest
                callback!

            # filter-options :: [Item] -> String -> [Item]
            filter-options: (options) ~> options
            
            # uid :: (Equatable e) => Item -> e
            uid: (.latest)

            # render-option :: Item -> ReactElement
            render-option: ({name, version, latest, new-option}?) ~>
                div class-name: \simple-option, style: font-size: 12,
                    if !!name
                        div null,
                            span style: font-weight: \bold, name
                            span null, "@#{version}"
                    div null, 
                        if !!new-option
                            span null, "Add "
                        span class-name: \link, latest
            
            # render-value :: Item -> ReactElement
            render-value: ({latest}?) ~> 
                div class-name: \simple-value, latest

            # render-no-results-found :: a -> ReactElement
            render-no-results-found: ~>
                loading = @state.request != undefined
                div class-name: \no-results-found,
                    switch 
                    | loading => "loading results"
                    | !loading and @state.search.length == 0 =>  "type in a few characters to kick off autocomplete"
                    | @state.search.length > 0 and @state.search == @props.url => 
                        button do 
                            class-name: "copy-#{@props.id}"
                            'data-clipboard-target' : ".#{@props.id} input"
                            "copy to clipboard"
                    | @state.search.length > 0 and !(url-regex.test @state.search) => "invalid or incomplete url"
                    | @state.search.length > 0 and (@state.search in @props.ignore-urls) => "already added"
                    | _ =>  "no results found"

    # get-initial-state :: a -> UIState
    get-initial-state: ->
        libraries: []
        request: undefined
        search: ""

    # component-did-mount :: a -> Void
    component-did-mount: !-> new Clipboard ".copy-#{@props.id}"

    focus: -> @refs.select.focus!
        
module.exports = React.create-class do

    display-name: \SettingsDialog

    # get-default-props :: a -> Props
    get-default-props: ->
        # initial-urls :: [String]
        # initial-transpilation-language :: String
        # on-change :: ({urls: [String], transpilation-language: String}) -> Void
        # on-cancel :: a -> Void

    # render :: a -> ReactElement
    render:  ->
        div class-name: 'settings-dialog dialog',
            
            # TITLE
            div class-name: \header, "Settings"

            # COMPILATION
            div class-name: "section language",
                label null, "Language : "
                SimpleSelect do
                    value: 
                        label: @state.transpilation-language
                        value: @state.transpilation-language
                    on-value-change: ({value}, callback) ~>  @set-state {transpilation-language: value}, callback
                    options: <[livescript javascript babel]> |> map (language) ~> label: language, value: language

            # EXTERNAL LIBRARIES
            div class-name: "section libraries",
                label null, "Client side javascript libraries"
                div class-name: \libraries,

                    # LIST OF URLS
                    [0 til @state.urls.length] |> map (index) ~>
                        div key: index,
                            
                            # AUTOCOMPLETE
                            LibrarySelect do 
                                key: index
                                id: "select-#{index}"
                                ref: "select-#{index}"
                                url: @state.urls[index]
                                ignore-urls: @state.urls
                                on-change: (url) ~> @set-state urls: do ~> @state.urls[index] = url; @state.urls
                             
                            # DELETE URL
                            SimpleButton do
                                id: "remove-library"
                                color: \red
                                on-click: ~> @set-state urls: do ~> @state.urls.splice index, 1; @state.urls
                                \Remove
                    
                    # ADD URL BUTTON                    
                    SimpleButton do 
                        id: "add-library"
                        color: \green
                        on-click: ~> 
                            <~ @set-state urls: @state.urls ++ [""]
                            @refs["select-#{@state.urls.length - 1}"].focus!
                        \Add
                    
            # OK / CANCEL
            div class-name: \footer,
                SimpleButton do
                    id: "save-settings"
                    color: \grey
                    on-click: ~> @props.on-change do
                        urls: @state.urls
                        transpilation-language: @state.transpilation-language
                    \Done
                SimpleButton do
                    id: "cancel-settings"
                    color: \grey
                    on-click: ~> @props.on-cancel!
                    \Cancel

    # get-initial-state :: a -> UIState
    get-initial-state: ->
        urls: @props.initial-urls
        transpilation-language: @props.initial-transpilation-language

