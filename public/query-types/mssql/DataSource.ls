{DOM:{a, div, input, label, option, select, textarea}}:React = require \react
$ = require \jquery-browserify
{each, find, map, sort-by} = require \prelude-ls

module.exports = React.create-class {

    render: ->
        {connection-name} = @.props.data-source
        current-connection = find (.value == connection-name), @.state.connections
        connections = (if typeof current-connection == \undefined then [{label: "- (#{connection-name})", value: connection-name}] else []) ++ (sort-by (.label), @.state.connections)
        div {class-name: 'data-source mssql-data-source'},
            div null,
                label null, \connection
                select {
                    value: connection-name
                    on-change: ({current-target:{value}}) ~>
                        new-data-source = {connection-name: value}
                        <[server user password database]> |> each (key) ~> 
                            if value == \custom
                                new-data-source[key] = @.props.data-source?[key] or ""
                            else
                                new-data-source[key] = undefined
                        @.props.on-change {} <<< @.props.data-source <<< new-data-source
                },
                    [{label: \custom, value: \custom}] ++ connections |> map -> option {key: it.value, value: it.value}, it.label
            if connection-name == \custom
                <[server user password database]> |> map (key) ~>
                    div {key},
                        label null, key
                        input {
                            type: \text
                            value: @.props.data-source[key]
                            on-change: ({current-target:{value}}) ~> @.props.on-change {} <<< @.props.data-source <<< {"#{key}": value}
                        }

    get-initial-state: ->
        connections: []

    component-did-mount: ->
        ($.getJSON \/apis/queryTypes/mssql/connections, '') .done ({connections or []}) ~> @.set-state {connections}

}