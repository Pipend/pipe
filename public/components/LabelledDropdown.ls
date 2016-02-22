{create-factory, DOM:{div, option, select, span}}:React = require \react
{find, map, filter} = require \prelude-ls
SimpleSelect = create-factory (require \react-selectize).SimpleSelect

module.exports = React.create-class do

    display-name: \LabelledDropdown

    # get-default-props :: a -> Props
    get-default-props: ->
        class-name: ""
        disabled: false
        editable: false
        label: ""
        options: [] # :: [Item], Where Item :: {label :: String, value :: String, color :: String}
        on-change: (value) !-> # String -> Void
        value: undefined

    # render :: a -> ReactElement
    render: ->
        {disabled, value, options} = @props
        div class-name: "labelled-dropdown #{@props.class-name}",
            React.DOM.label null, @props.label
            SimpleSelect {
                disabled
                theme: \dark
                value: 
                    | typeof value == \undefined => undefined
                    | _ =>
                        {label, color}? = (options ? []) |> find (.value == value)
                        {label, value, color}
                on-value-change: ({value}?, callback) ~> 
                    @props.on-change value
                    callback!
                restore-on-backspace: -> it.label.substr 0, it.label.length - 1
                render-value: ({label, color}?) ~>
                    div class-name: \simple-value,
                        span do 
                            style: 
                                color: if !!disabled then \black else color
                            label
                render-option: ({label, color, new-option}?) ~>
                    div class-name: \simple-option,
                        span style: {color}, if !!new-option then "Add #{label} ..." else label
                uid: ~> "#{it.value}#{it.color}#{@props.disabled}"
                options: options |> filter -> !!it.value
                style: if @props.disabled then {opacity: 0.4} else {}
            } <<< (
                if @props.editable 
                    create-from-search: (options, search) ->
                        return null if search.length == 0 or search in map (.label), options
                        label: search, value: search
                else
                    {}
            )