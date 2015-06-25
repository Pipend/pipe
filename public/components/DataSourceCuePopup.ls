{all, camelize, concat-map, filter, keys, obj-to-pairs, map, pairs-to-obj, reject} = require \prelude-ls
{DOM:{div}}:React = require \react
LabelledDropdown = require \./LabelledDropdown.ls
LabelledTextField = require \./LabelledTextField.ls
SimpleButton = require \./SimpleButton.ls
ui-protocol =
    mongodb: require \../query-types/mongodb/ui-protocol.ls
    mssql: require \../query-types/mssql/ui-protocol.ls
    multi: require \../query-types/multi/ui-protocol.ls
    curl: require \../query-types/curl/ui-protocol.ls
    
module.exports = React.create-class {

    render: ->
        
        connection-kinds-from-query-type = (query-type) ->
            {
                supports-connection-string
                partial-data-source-cue-component
                complete-data-source-cue-component
            }? = ui-protocol[query-type].data-source-cue-popup-settings!
            connection-kind = (if supports-connection-string then <[connection-string]> else []) ++
                              (if !!partial-data-source-cue-component then <[pre-configured]> else []) ++
                              (if !!complete-data-source-cue-component then <[complete]> else [])
                                |> filter -> !!it
                                |> concat-map -> label: (it.replace \-, ' '), value: it

        # data-source-cue is complete by default if the ui-protocol does not provide any component for changing the data-source-cue
        # complete-by-default :: String -> Bool
        complete-by-default = (query-type) ->
            {
                supports-connection-string
                partial-data-source-cue-component
                complete-data-source-cue-component
            }? = ui-protocol[query-type].data-source-cue-popup-settings!
            [supports-connection-string, partial-data-source-cue-component, complete-data-source-cue-component] |> all -> !it
        
        div {class-name: 'data-source-cue-popup popup', style: {left: @props?.left 360}},

            # lists all the available query types (like mongodb, mssql, multi, curl, ...)
            React.create-element do 
                LabelledDropdown
                label: 'query type'
                value: @props.data-source-cue.query-type
                options: ui-protocol
                    |> keys
                    |> map -> {label: it, value: it}
                on-change: (value) ~>
                    {connection-kind} = @props.data-source-cue
                    @props?.on-change do 
                        query-type: value
                        connection-kind: 
                            | connection-kind in (connection-kinds-from-query-type value) => connection-kind
                            | _ => null
                        complete: complete-by-default value

            # lists all the connection kinds
            if connection-kind.length > 0
                React.create-element do 
                    LabelledDropdown
                    label: 'conn. kind'
                    value: @props.data-source-cue.connection-kind
                    options: connection-kinds-from-query-type @props.data-source-cue.query-type
                    on-change: (value) ~> 
                        {query-type} = @props.data-source-cue
                        @.props?.on-change do
                            query-type: query-type
                            connection-kind: value
                            complete: complete-by-default query-type

            # renders a new data-source component based on the value of the "query-type" dropdown
            if @props.data-source-cue.connection-kind != \connection-string
                data-source-cue-component-name = 
                    | @props.data-source-cue.connection-kind == \pre-configured => \partial-data-source-cue-component 
                    | _ => \complete-data-source-cue-component
                component = ui-protocol[@props.data-source-cue.query-type].data-source-cue-popup-settings![camelize data-source-cue-component-name]
                if !!component
                    React.create-element do
                        component
                        {on-change: @props.on-change, data-source-cue: @props.data-source-cue}

            # render "connection-string" component if the query-type supports it            
            else if ui-protocol[@props.data-source-cue.query-type].data-source-cue-popup-settings!.supports-connection-string
                div null,
                    React.create-element do 
                        LabelledTextField
                        label: 'conn. string'
                        value: @props.data-source-cue.connection-string
                        on-change: (value) ~>
                            @.props.on-change {} <<< @.props.data-source-cue <<< {connection-string: value, complete: false}
                    React.create-element do 
                        SimpleButton
                        label: \Apply
                        pressed: @props.data-source-cue.complete
                        on-click: ~> @props.on-change {} <<< @props.data-source-cue <<< {complete:true}

}