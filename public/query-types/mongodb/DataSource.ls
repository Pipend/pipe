{DOM:{a, div, input, label, option, select, textarea}}:React = require \react
{camelize, each, find, map, sort, sort-by} = require \prelude-ls
$ = require \jquery-browserify

module.exports = React.create-class {

    render: ->

        {connection-name, database, collection} = @.props
        
        connections = @.state.connections
        databases = @.state.databases |> map -> {label: it, value: it}
        collections = @.state.collections |> map -> {label: it, value: it}

        [connections, databases, collections] = [[connection-name, connections], [database, databases], [collection, collections]]
            |> map ([value, options]) ->
                (if typeof (options |> find (.value == value)) == \undefined then [{label: "- (#{value})", value}] else []) ++ (options |> sort-by (.label))

        div {class-name: \mongodb-data-source}, 
            [
                {
                    name: \server
                    value: connection-name
                    options: connections
                    disabled: false
                    on-change: ({current-target:{value}}) ~> @.props.on-change {} <<< @.props <<< {connection-name: value}
                }
                {
                    name: \database
                    value: database
                    options: databases
                    disabled: @.state.loading-databases
                    on-change: ({current-target:{value}}) ~> @.props.on-change {} <<< @.props <<< {database: value}
                }
                {
                    name: \collection
                    value: collection
                    options: collections
                    disabled: @.state.loading-collections
                    on-change: ({current-target:{value}}) ~> @.props.on-change {} <<< @.props <<<< {collection: value}
                }
            ] |> map ({name, value, options, disabled, on-change}) ~>
                div {key: name},
                    label null, name
                    select {disabled, value, on-change},
                        options |> map -> option {key: it.value, value: it.value}, it.label

    get-initial-state: -> {connections: [], databases: [], collections: [], loading-databases: false, loading-collections: false}

    update-options: (prev-props, props) ->

        load-collections = (params) ~>
            @.set-state {loading-collections: true}
            @.collections-request.abort! if !!@.collections-request
            @.collections-request = $.getJSON \/apis/queryTypes/mongodb/connections, params
                ..done ({collections or []}) ~>
                    @.set-state {collections, loading-collections: false}
                    @.props.on-change {} <<< @.props <<< {collection : collections.0} if !(props.collection in collections)

        if prev-props?.connection-name != props?.connection-name
            @.set-state {loading-databases: true, loading-collections: true}
            @.databases-request.abort! if !!@.databases-request
            @.databases-request = $.getJSON \/apis/queryTypes/mongodb/connections, {connection-name: props.connection-name}
                ..done ({databases or []}) ~>
                    @.set-state {databases, loading-databases: false}
                    database = 
                        | props.database in databases => props.database
                        | _ => databases.0
                    @.props.on-change {} <<< @.props <<< {database}
                    load-collections {connection-name: props.connection-name, database}

        else if prev-props?.database != props?.database
            load-collections {connection-name: props.connection-name, database: props.database}

    component-did-mount: ->
        ($.getJSON \/apis/queryTypes/mongodb/connections, '') .done ({connections or []}) ~> @.set-state {connections}
        @.update-options {}, @.props

    component-will-receive-props: (props) -> @.update-options @.props, props


}
