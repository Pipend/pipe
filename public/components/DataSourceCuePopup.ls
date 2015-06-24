{camelize, keys, obj-to-pairs, map, pairs-to-obj, reject} = require \prelude-ls
{DOM:{div, input, label, option, select}}:React = require \react
ui-protocol =
    mongodb: require \../query-types/mongodb/ui-protocol.ls
    mssql: require \../query-types/mssql/ui-protocol.ls
    multi: require \../query-types/multi/ui-protocol.ls
    curl: require \../query-types/curl/ui-protocol.ls
    
module.exports = React.create-class {

    render: ->
        
        connection-kind = 
            * label: 'Connection string'
              value: \connection-string
            * label: 'Pre configured'
              value: \pre-configured
            * label: 'Complete'
              value: \complete
              
        div {class-name: 'data-source-cue-popup popup', style: {left: @props?.left 360}},

            # lists all the connection kinds
            div null,
                label null, 'conn. kind'
                select do
                    {
                        value: @props.data-source-cue.connection-kind
                        on-change: ({current-target:{value}}) ~> 
                            @.props?.on-change do
                                query-type: @props.data-source-cue.query-type
                                connection-kind: value
                                complete: false
                    }
                    connection-kind |> map ~> option {key: it.value, value: it.value}, it.label

            # lists all the available query types (like mongodb, mssql, multi, curl, ...)
            div null,
                label null, 'query type'
                select do 
                    {
                        value: @props.data-source-cue.query-type
                        on-change: ({current-target:{value}}) ~> 
                            @props?.on-change do 
                                query-type: value
                                connection-kind: @props.data-source-cue.connection-kind
                                complete: false
                    }
                    ui-protocol
                        |> keys
                        |> map -> option {key: it, value: it}, it

            # renders a new data-source component based on the value of the "query-type" dropdown
            if @props.data-source-cue.connection-kind != \connection-string
                data-source-cue-component-name = 
                    | @props.data-source-cue.connection-kind == \pre-configured => \partial-data-source-cue-component 
                    | _ => \complete-data-source-cue-component
                React.create-element do
                    ui-protocol[@props.data-source-cue.query-type][camelize data-source-cue-component-name]
                    {on-change: @props.on-change, data-source-cue: @props.data-source-cue}

            else if @props.data-source-cue.query-type in <[mongodb mssql]>
                div null,
                    div null,
                        label null, 'conn. string'
                        input do
                            type: \text
                            value: @props.data-source-cue.connection-string
                            on-change: ({current-target:{value}}) ~>
                                @.props.on-change {} <<< @.props.data-source-cue <<< {connection-string: value, complete: false}
                    div do
                        {
                            style:
                                background: if @props.data-source-cue.complete then \green else \red 
                            on-click: ~> @props.on-change {} <<< @props.data-source-cue <<< {complete:true}
                        }
                        \complete

}