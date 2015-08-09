{filter, find, fold, map, any, sort-by, zip, take, drop} = require \prelude-ls
{DOM:{button, div, h1, label, input, a, span, select, option}}:React = require \react
AutoComplete = React.create-factory require \react-auto-complete

module.exports = React.create-class do

    # props :: 
    #   urls :: [String]
    #   on-change :: ({urls: [String], transpilation-language: String}) -> Void
    #   on-cancel :: () -> Void

    render:  ->

        # compilation
        div { class-name: \settings },
            div { class-name: \section},
                div {style: {margin-bottom: "1em"}}, "Select MongoDB query language / Transformation and Presentation language:"
                select {
                    style: 
                        margin-right: "1em"
                    value: @state.transpilation-language
                    on-change: ({current-target:{value}}) ~> 
                        <- @set-state transpilation-language: value
                }, 
                    ['livescript', 'javascript'] |> map (k) ~> 
                        option {key: k, value: k}, k

            # external libraries
            div { class-name: \section },
                div {style: {margin-bottom: "1em"}}, "Client-side JavaScript libraries"
                React.create-element ClientExternalLibs,
                    {
                        initial-urls: @state.urls
                        on-change: (urls) ~>
                            @set-state {
                                urls: urls
                            }
                    }

            # ok / cancel
            div { class-name: "section buttons" },
                div { class-name: "wrapper" },
                    button {
                        on-click: ~>
                            @props.on-cancel!
                    }, "Cancel"
                    button {
                        on-click: ~>
                            @props.on-change {
                                urls: @state.urls
                                transpilation-language: @state.transpilation-language
                            }
                    }, "OK"

    get-initial-state: ->
        urls: @props.initial-urls
        transpilation-language: @props.initial-transpilation-language

ClientExternalLibs = React.create-class do 

    # props :: {urls :: [String], on-change :: ([String]) -> Void }

    render: ->
        
        div { class-name: \client-external-libs-dailog }, 
            div { class-name: "list" }, 
                @state.urls `zip` [0 til @state.urls.length]
                    |> map ([, index]) ~>
                        
                        url-regex = /^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$/

                        div { class-name: "element #{if @state.urls[index]?.valid ? true then 'valid' else 'invalid'}" },
                            AutoComplete do
                                placeholder: "Script Url"
                                option-class: ScriptOption
                                value: @state.urls[index]?.url ? ""
                                options: @state.scripts
                                on-blur: (value) ~>
                                    valid = url-regex.test value
                                    @set-state { urls: do ~> @state.urls[index] = {url: value, valid}; @state.urls }

                                on-change: (value) ~>
                                    #@set-state selected-script: value
                                    @request.abort! if !!@request
                                    @request = $.getJSON "http://api.cdnjs.com/libraries?fields=version,homepage,keywords&search=#{value}"
                                        ..done (scripts) ~> @set-state {
                                            scripts: scripts?.results |> take 20 
                                                |> map ({name, version, latest}) -> name: "#{name} (#{version})", value: latest
                                        }

                                    valid = url-regex.test value
                                    @set-state { urls: do ~> @state.urls[index] = {url: value} <<< (if valid then {valid} else {}); @state.urls }
                                    @props.on-change <| @state.urls |> filter (.valid) |> map (.url)

                            if index < 1 then span {class-name: 'x'}, "" else span { 
                                class-name: 'x'
                                on-click: ~>
                                    @set-state { urls: do ~> @state.urls.splice index, 1; @state.urls }
                            }, "×"
            div { class-name: "add" },
                button {on-click: ~> @set-state {urls: @state.urls ++ [""]}}, "Add"
        

    get-initial-state: -> 
        scripts: []
        urls: @props.initial-urls ++ (if @props.initial-urls.length == 0 then [""] else []) 
            |> map (url) -> {url, valid: true}



ScriptOption = React.create-class do

    display-name: \ScriptOption

    statics:

        # [ScriptOption] -> String -> [ScriptOption]
        filter: (list, search) -> list

    # a -> ReactElement
    render: ->

        {focused, name, value} = @props

        # ScriptOption
        div do 
            {
                class-name: "script-option #{if focused then 'focused' else ''}"
            }
            div style:{font-weight: \bold}, name
            div style:{font-size: \0.8em}, value ? ""