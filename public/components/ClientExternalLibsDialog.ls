{filter, find, fold, map, any, sort-by, zip, take, drop} = require \prelude-ls
{DOM:{button, div, h1, label, input, a, span}}:React = require \react
AutoComplete = React.create-factory require \react-auto-complete

module.exports = React.create-class do 

    render: ->
        
        div { class-name: \client-external-libs-dailog }, 
            div { }, 
                @state.urls `zip` [0 til @state.urls.length]
                    |> map ([, index]) ~>
                        div { class-name: "element #{if @state.urls[index]?.valid ? false then 'valid' else 'invalid'}" },
                            AutoComplete do
                                option-class: ScriptOption
                                value: @state.urls[index]?.url ? ""
                                options: @state.scripts
                                on-change: (value) ~>
                                    #@set-state selected-script: value
                                    @request.abort! if !!@request
                                    @request = $.getJSON "http://api.cdnjs.com/libraries?fields=version,homepage,keywords&search=#{value}"
                                        ..done (scripts) ~> @set-state {
                                            scripts: scripts?.results |> take 20 
                                                |> map ({name, version, latest}) -> name: "#{name} (#{version})", value: latest
                                        }

                                    valid = /^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$/.test value
                                    @set-state { urls: do ~> @state.urls[index] = {url: value, valid}; @state.urls }
                            if index < 1 then span {class-name: 'x'}, "" else span { 
                                class-name: 'x'
                                on-click: ~>
                                    @set-state { urls: do ~> @state.urls.splice index, 1; @state.urls }
                            }, "×"
            button {on-click: ~> @set-state {urls: @state.urls ++ [""]}}, "Add"
            button {
                on-click: ~> 
                    @props.on-change <| @state.urls |> filter (-> !!it)
            }, "OK"
        

    get-initial-state: -> 
        scripts: []
        urls: @props.initial-urls |> map (url) -> {url, valid: true}




ScriptOption = React.create-class do

    display-name: \ScriptOption

    statics:

        # [ScriptOption] -> String -> [ScriptOption]
        filter: (list, search) -> list

    # a -> ReactElement
    render: ->

        {on-click, on-mouse-over, on-mouse-out, focused, name, value} = @props

        # ScriptOption
        div do 
            {
                class-name: "script-option #{if focused then 'focused' else ''}"
                on-click
                on-mouse-over
                on-mouse-out
            }
            div style:{font-weight: \bold}, name
            div style:{font-size: \0.8em}, value ? ""