{DOM:{a, div, input, label, option, select, textarea}}:React = require \react
LabelledDropdown = require \./LabelledDropdown.ls
LabelledTextField = require \./LabelledTextField.ls
{map, obj-to-pairs, pairs-to-obj, split, Str} = require \prelude-ls
querystring = require \querystring

module.exports = React.create-class {

    render: ->
        latest-query-segment = if @state.use-latest-query then "" else "/queries/#{@props.query-id}"        
        cache-segment = if @state.cache == \sliding then @state.cache-expiry else @state.cache
        image-size = 
            | @state.format == \png => "#{@state.width}/#{@state.height}"
            | _ => ''
        data-source-cue-params =
            | @state.include-data-source =>
                @props.data-source-cue
                    |> obj-to-pairs
                    |> map ([key, value]) -> ["dsc-#{key}", value]
                    |> pairs-to-obj
            | _ => {}
        query-string = querystring.stringify {} <<< @props.parameters <<< data-source-cue-params
        href = decode-URI-component match @state.export 
            | true => "http://#{@props.host}/apis/branches/#{@props.branch-id}#{latest-query-segment}/export/#{cache-segment}/#{@state.format}/#{image-size}?#{query-string}"
            | _ => "http://#{@props.host}/apis/branches/#{@props.branch-id}#{latest-query-segment}/execute/#{cache-segment}/#{@state.display}?#{query-string}"
        div {class-name: 'share-popup popup', style: {left: @props?.left 360}},

            div null,
                label {html-for: \export}, 'export'
                input {
                    id: \export
                    type: \checkbox
                    checked: @state.export
                    on-change: ({current-target:{checked}}) ~> @set-state {export: checked} 
                }

            if @state.export 
                
                React.create-element do
                    LabelledDropdown
                    label: \format
                    value: @state.format
                    options: <[txt json png]> |> map -> {label: it, value: it}
                    on-change: (value) ~> @set-state {format: value}                

            else
                React.create-element do 
                    LabelledDropdown
                    label: \display
                    value: @state.display
                    options: <[query transformation presentation]> |> map -> {label: it, value: it}
                    on-change: (value) ~> @set-state {display: value}

            if @state.export and @state.format == \png
                <[width height]> |> map (field-name) ~>
                    React.create-element do 
                        LabelledTextField
                        label: field-name
                        value: @state[field-name]
                        on-change: (value) ~> @set-state {"#{field-name}": value}

            div null,
                label {html-for: \use-latest-query}, 'use latest query'
                input {
                    id: \use-latest-query
                    type: \checkbox
                    checked: @state.use-latest-query
                    on-change: ({current-target:{checked}}) ~> @set-state {use-latest-query: checked} 
                }

            React.create-element do 
                LabelledDropdown
                label: \cache
                options: <[true false sliding]> |> map -> {label: it, value: it}
                value: @state.cache
                on-change: (value) ~> @set-state {cache: value}

            if @state.cache == \sliding
                React.create-element do 
                    LabelledTextField
                    label: 'cache expiry'
                    value: @state.cache-expiry
                    on-change: (value) ~> @set-state {cache-expiry: value}

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
        export: false
        display: \presentation
        use-latest-query: true
        cache: \false
        cache-expiry: 0
        include-data-source: false
        format: \png
        width: 1280
        height: 720

}
