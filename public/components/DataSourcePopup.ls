{keys, obj-to-pairs, map, pairs-to-obj, reject} = require \prelude-ls
{DOM:{div, label, option, select}}:React = require \react
ui-protocol =
    mongodb: require \../query-types/mongodb/ui-protocol.ls
    mssql: require \../query-types/mssql/ui-protocol.ls
    multi: require \../query-types/multi/ui-protocol.ls
    curl: require \../query-types/curl/ui-protocol.ls
    
module.exports = React.create-class {

    render: ->
        div {class-name: 'data-source-popup popup', style: {left: @.props?.left 360}},
            div null,
                label null, 'query type'
                select do 
                    {
                        value: @.props.data-source.type
                        on-change: ({current-target:{value}}) ~> @.props?.on-change ui-protocol[value].get-empty-data-source!
                    }
                    ui-protocol
                        |> keys
                        |> map -> option {value: it}, it
            React.create-element do 
                ui-protocol[@.props.data-source.type].data-source-component
                {} <<< {data-source: @.props.data-source} <<< {on-change: @.props.on-change}

}