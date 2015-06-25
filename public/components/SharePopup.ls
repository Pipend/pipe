{DOM:{a, div, input, label, option, select, textarea}}:React = require \react
{map, obj-to-pairs, pairs-to-obj, split, Str} = require \prelude-ls
querystring = require \querystring

module.exports = React.create-class {

    render: ->
        latest-query-segment = if @state.use-latest-query then "" else "/queries/#{@props.query-id}"        
        cache-segment = if @state.cache == \sliding then @state.cache-expiry else @state.cache
        data-source-cue-params =
            | @state.include-data-source =>
                @props.data-source-cue
                    |> obj-to-pairs
                    |> map ([key, value]) -> ["dsc-#{key}", value]
                    |> pairs-to-obj
            | _ => {}
        query-string = querystring.stringify {} <<< @props.parameters <<< data-source-cue-params
        href = decode-URI-component "http://#{@props.host}/apis/branches/#{@props.branch-id}#{latest-query-segment}/execute/#{cache-segment}/#{@state.display}?#{query-string}"
        div {class-name: 'share-popup popup', style: {left: @props?.left 360}},
            div null,
                label null, \display
                select {
                    value: @state.display
                    on-change: ({current-target:{value}}) ~> @set-state {display: value}
                },
                    option {value: \query}, \query
                    option {value: \transformation}, \transformation
                    option {value: \presentation}, \presentation                    
            div null,
                label {html-for: \use-latest-query}, 'use latest query'
                input {
                    id: \use-latest-query
                    type: \checkbox
                    checked: @state.use-latest-query
                    on-change: ({current-target:{checked}}) ~> @set-state {use-latest-query: checked} 
                }
            div null,
                label null, \cache
                select {
                    value: @state.cache
                    on-change: ({current-target:{value}}) ~> @set-state {cache: value}
                },
                    <[true false sliding]> |> map ->
                        option {value: it}, it
            if @state.cache == \sliding
                div null,
                    label null, 'cache expiry'
                    input {type: \text, value: @state.cache-expiry, on-change: ({current-target:{value}}) ~> @set-state {cache-expiry: value}}
            div null,
                label {html-for: \include-data-source}, 'include data source'
                input {
                    id: \include-data-source
                    type: \checkbox
                    checked: @state.include-data-source
                    on-change: ({current-target:{checked}}) ~> @set-state {include-data-source: checked} 
                }
            a {href, target: "_blank"}, href

    get-initial-state: ->
        {display: \presentation, use-latest-query: true, cache: \false, cache-expiry: 0, include-data-source: false}
}
