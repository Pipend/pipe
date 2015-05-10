{map} = require \prelude-ls
{DOM:{div, label, option, select}}:React = require \react
ui-protocol =
    mongodb: require \../query-types/mongodb/ui-protocol.ls
    mssql: require \../query-types/mssql/ui-protocol.ls

module.exports = React.create-class {

    render: ->
        div {class-name: 'data-source-popup popup'},
            div null,
                label null, 'query type'
                select do 
                    {
                        value: @.props.data-source.type
                        on-change: ({current-target:{value}}) ~> @.props?.on-change ui-protocol[value].get-empty-data-source!
                    }
                    <[mongodb mssql curl multiquery]>
                        |> map -> option {value: it}, it
            React.create-element do 
                @.props.data-source-component
                {} <<< @.props.data-source <<< {on-change: @.props.on-change}

}