{DOM:{a, div, input, label, option, select, textarea}}:React = require \react
$ = require \jquery-browserify
{find, map, sort-by} = require \prelude-ls

module.exports = React.create-class {

    render: ->
        {connection-name} = @.props.data-source
        current-connection = find (.value == connection-name), @.state.connections
        connections = (if typeof current-connection == \undefined then [{label: "- (#{connection-name})", value: connection-name}] else []) ++ (sort-by (.label), @.state.connections)
        div {class-name: \mssql-data-source},
            div null,
                label null, \server
                select {value: connection-name, on-change: ({current-target:{value}}) ~> @.props.on-change {} <<< @.props.data-source <<< {connection-name: value}},
                    connections |> map -> option {key: it.value, value: it.value}, it.label

    get-initial-state: ->
        connections: []

    component-did-mount: ->
        ($.getJSON \/apis/queryTypes/mssql/connections, '') .done ({connections or []}) ~> @.set-state {connections}

}