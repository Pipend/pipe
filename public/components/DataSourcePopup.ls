{keys, obj-to-pairs, map, pairs-to-obj, reject} = require \prelude-ls
{DOM:{div, label, option, select}}:React = require \react
ui-protocol =
    mongodb: require \../query-types/mongodb/ui-protocol.ls
    mssql: require \../query-types/mssql/ui-protocol.ls

module.exports = React.create-class {

    render: ->
        div {class-name: 'data-source-popup popup', style: {left: @.props?.left}},
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
                @.props.data-source-component
                {} <<< @.props.data-source <<< {
                    on-change: (data-source) ~>
                        @.props.on-change do 
                            data-source
                                |> obj-to-pairs
                                |> reject ([key]) ~> key in <[onChange]>
                                |> pairs-to-obj
                }

}