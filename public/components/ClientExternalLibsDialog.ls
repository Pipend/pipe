{filter, find, fold, map, sort-by, zip, take, drop} = require \prelude-ls
{DOM:{button, div, h1, label, input, a, span}}:React = require \react

Autocomplete = require 'react-autocomplete'
window.Autocomplete = Autocomplete
window.h1 = h1


module.exports = React.create-class do 

    render: ->
        
        div { }, 
            div { }, 
                @state.urls `zip` [0 til @state.urls.length]
                    |> map ([url, index]) ~>
                        div { style: display: "flex", justify-content: "space-between", width: "200px" },
                            React.create-element LibInput, {
                                style: width: "180px"
                                url: url
                                on-change: (url) ~> 
                                    @set-state {urls: do ~> @state.urls[index] = url; @state.urls}
                            }
                            if index < 1 then span null, "" else a { 
                                style: color: "white"
                                on-click: ~>
                                    @set-state {urls: do ~> @state.urls.splice index, 1; @state.urls}
                            }, "X"
            button {on-click: ~> @set-state {urls: @state.urls ++ ["untitled"]}}, "Add"
            button {on-click: ~> @props.on-change @state.urls}, "OK"
        

    get-initial-state: -> 
        urls: @props.initial-urls # ["underscore"]


LibInput = React.create-class do
    render: ->
        React.create-element do 
            ComboboxOption #TODO: https://github.com/rackt/react-autocomplete/blob/master/examples/basic/main.js
            # Autocomplete.Typeahead 
            # {
            #     default-value: "underscore"
            #     name: "urlselector"
            #     options: ["underscore", "lodash", "heatmap"]
            # }
            # div { style: background-color: "red"}, ""

        # div { 
        #     style: {
        #         width: "100%"
        #         border: "2px solid red"
        #     }  <<< @props.style 
        # }, 
            # input {
            #     style: width: "100%"
            #     type: "text"
            #     placeholder: "Enter the URL here"
            #     value: @props.url
            #     on-change: ({current-target:{value}}) ~> @props.on-change value 
            # }, null

    get-initial-state: -> 
        {}

    get-default-props: ->

