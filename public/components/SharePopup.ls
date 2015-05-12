{DOM:{a, div, input, label, option, select, textarea}}:React = require \react
{map} = require \prelude-ls
querystring = require \querystring

module.exports = React.create-class {

    render: ->
        dynamic-segments = if @.state.use-latest-query then "branches/#{@.props.branch-id}" else "queries/#{@.props.query-id}"
        query-string = querystring.stringify {} <<< {
            cache: if @.state.cache == \sliding then @.state.cache-expiry else @.state.cache
            display: @.state.display
        } <<< @.props.parameters
        href = decode-URI-component "http://#{@.props.host}/apis/#{dynamic-segments}/execute?#{query-string}"
        div {class-name: 'share-popup popup', style: {left: @.props?.left}},
            div null,
                label null, \display
                select {
                    value: @.state.display
                    on-change: ({current-target:{value}}) ~> @.set-state {display: value}
                },
                    option {value: \query}, \query
                    option {value: \transformation}, \transformation
                    option {value: \presentation}, \presentation                    
            div null,
                label {html-for: \use-latest-query}, 'use latest query'
                input {
                    id: \use-latest-query
                    type: \checkbox
                    checked: @.state.use-latest-query
                    on-change: ({current-target:{checked}}) ~> @.set-state {use-latest-query: checked} 
                }
            div null,
                label null, \cache
                select {
                    value: @.state.cache
                    on-change: ({current-target:{value}}) ~> @.set-state {cache: value}
                },
                    <[true false sliding]> |> map ->
                        option {value: it}, it
            if @.state.cache == \sliding
                div null,
                    label null, 'cache expiry'
                    input {type: \text, value: @.state.cache-expiry, on-change: ({current-target:{value}}) ~> @.set-state {cache-expiry: value}}
            a {href, target: "_blank"}, href

    get-initial-state: ->
        {display: \presentation, use-latest-query: true, cache: \false, cache-expiry: 0}
}
