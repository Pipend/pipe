{create-factory, DOM:{a, div, input, label, option, select, textarea}}:React = require \react
LabelledDropdown = create-factory require \./LabelledDropdown.ls
LabelledTextField = create-factory require \./LabelledTextField.ls
{map, obj-to-pairs, pairs-to-obj, split, Str} = require \prelude-ls
require! \querystring

module.exports = React.create-class do

    display-name: \SharePopup

    # get-default-props :: a -> Props
    get-default-props: ->
        branch-id: ""
        data-source-cue: {}
        host: ""
        # left :: Number -> Number
        parameters: {}
        query-id: ""

    # render :: a -> ReactElement
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
        
        # SHARE POPUP
        div do 
            class-name: 'share-popup popup'
            style: left: @props?.left 360

            # EXPORT CHECKBOX
            div null,
                label {html-for: \export}, 'export'
                input do
                    id: \export
                    type: \checkbox
                    checked: @state.export
                    on-change: ({current-target:{checked}}) ~> @set-state {export: checked} 

            if @state.export 

                # EXPORT IMAGE FORMAT
                LabelledDropdown do
                    label: \format
                    value: @state.format
                    options: <[txt json png]> |> map -> {label: it, value: it}
                    on-change: (value) ~> @set-state {format: value}

            else
                
                # OUTPUT LAYER
                LabelledDropdown do
                    label: \display
                    value: @state.display
                    options: <[query presentation]> |> map -> {label: it, value: it}
                    on-change: (value) ~> @set-state {display: value}

            if @state.export and @state.format == \png

                # WIDTH & HEIGHT INPUT
                <[width height]> |> map (field-name) ~>
                    LabelledTextField do
                        key: field-name
                        label: field-name
                        value: @state[field-name]
                        on-change: (value) ~> @set-state {"#{field-name}": value}

            # USE LATEST QUERY CHECKBOX
            div null,
                label {html-for: \use-latest-query}, 'use latest query'
                input do
                    id: \use-latest-query
                    type: \checkbox
                    checked: @state.use-latest-query
                    on-change: ({current-target:{checked}}) ~> @set-state {use-latest-query: checked} 

            # CACHE DROPDOWN
            LabelledDropdown do
                label: \cache
                options: <[true false sliding]> |> map -> {label: it, value: it}
                value: @state.cache
                on-change: (value) ~> @set-state {cache: value}

            if @state.cache == \sliding

                # CACHE EXPIRATION INPUT
                LabelledTextField do
                    label: 'cache expiry'
                    value: @state.cache-expiry
                    on-change: (value) ~> @set-state {cache-expiry: value}

            # INCLUDE DATASOURCE CHECKBOX
            div null,
                label {html-for: \include-data-source}, 'include data source'
                input do
                    id: \include-data-source
                    type: \checkbox
                    checked: @state.include-data-source
                    on-change: ({current-target:{checked}}) ~> @set-state {include-data-source: checked} 

            # LINK TO SHARE
            a {href, target: "_blank"}, href

    # get-initial-state :: a -> UIState
    get-initial-state: ->
        cache: \false
        cache-expiry: 0
        display: \presentation
        export: false
        format: \png
        include-data-source: false
        use-latest-query: true
        width: 1280
        height: 720
