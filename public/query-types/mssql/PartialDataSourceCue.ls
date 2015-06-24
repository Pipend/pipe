{DOM:{a, div, input, label, option, select, textarea}}:React = require \react
$ = require \jquery-browserify
{each, find, map, sort-by} = require \prelude-ls

module.exports = React.create-class {

    render: ->
        {connection-name} = @props.data-source-cue
        connections =
            | typeof (@state.connections |> find (.value == connection-name)) == \undefined => [label: "- (#{connection-name})", value: connection-name]
            | _ => []
        connections ++= @state.connections |> sort-by (.label)
        div {class-name: 'mssql partial data-source-cue'},
            div null,
                label null, \connection
                select {
                    value: connection-name
                    on-change: ({current-target:{value}}) ~> 
                        default-database = (@state.connections |> find (.value == value)).default-database
                        @props.on-change {} <<< @props.data-source-cue <<<
                            connection-name: value, 
                            database: default-database
                            complete: !!default-database
                },
                    connections |> map -> option {key: it.value, value: it.value}, it.label
            div null,
                label null, \database
                input do
                    type: \text
                    value: @props.data-source-cue?.database or ""
                    on-change: ({current-target:{value}}) ~>
                        @props.on-change {} <<< @props.data-source-cue <<< {database: value, complete: false}
            div do
                {
                    style:
                        background: if @props.data-source-cue.complete then \green else \red 
                    on-click: ~> @props.on-change {} <<< @props.data-source-cue <<< {complete:true}
                }
                \complete

    get-initial-state: ->
        connections: []

    component-did-mount: ->
        ($.getJSON \/apis/queryTypes/mssql/connections, '') .done ({connections or []}) ~> @set-state {connections}

}