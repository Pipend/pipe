{create-factory, DOM:{a, div, input, label, option, select, textarea}}:React = require \react
LabelledDropdown = create-factory require \../../components/LabelledDropdown.ls
{all, camelize, each, find, map, sort, sort-by} = require \prelude-ls
$ = require \jquery-browserify

module.exports = React.create-class do

    # get-default-props :: a -> Props
    get-default-props: ->
        data-source-cue: {} # :: {connection-name :: String, database :: String, collection :: String}
        editable: false

    # render :: a -> ReactElement
    render: ->

        {connection-name, database, collection} = @props.data-source-cue
        
        connections = @state.connections
        databases = @state.databases |> map -> {label: it, value: it}
        collections = @state.collections

        # replace the selected values with "-({value})" if they are not found in their corresponding collections        
        [connections, databases, collections] = [[connection-name, connections], [database, databases], [collection, collections]]
            |> map ([value, options]) ->
                (if typeof (options |> find (.value == value)) == \undefined and typeof value == \string then [{label: value, value, color: \red}] else []) ++ (options |> sort-by (.label))

        div {class-name: 'mongodb partial data-source-cue'}, 
            [
                {
                    name: 'connection'
                    value: connection-name
                    options: connections
                    disabled: false
                    on-change: (value) ~> @update-props @props, {connection-name: value}
                }
                {
                    name: \database
                    value: database
                    options: databases
                    disabled: @state.loading-databases
                    on-change: (value) ~> @update-props @props, {database: value}
                }
                {
                    name: \collection
                    value: collection
                    options: collections
                    disabled: @state.loading-collections
                    editable: @props.editable
                    on-change: (value) ~> @update-props @props, {collection: value}
                }
            ] |> map ({name, value, options, disabled, editable, on-change}) ~>
                LabelledDropdown do
                    key: name
                    disabled: disabled 
                    editable: editable
                    label: name
                    value: value
                    options: options
                    on-change: (new-value) ~>
                        <~ do ~> (callback) ~> 
                            if new-value in map (.label), @state.collections 
                                callback! 
                            else 
                                @set-state do 
                                    collections: [{label: new-value, value: new-value, color: \green}] ++ @state.collections
                                    callback
                        on-change new-value

    # get-initial-state :: a -> UIState
    get-initial-state: -> 
        connections: [] # :: [{label :: String, value :: String}]
        databases: [] # :: [String]
        collections: [] # :: [{label :: String, value :: String, color :: String}]
        loading-databases: false
        loading-collections: false
    
    # update-props :: Props -> Map String, String -> Void
    update-props: (props, changes) !->
        new-data-source-cue = {} <<< props.data-source-cue <<< changes
        complete = <[connection-name database collection]> |> all ~> 
            !!new-data-source-cue?[camelize it] and (new-data-source-cue[camelize it].index-of '- (') != 0
        props.on-change new-data-source-cue <<< {complete}

    # getJSON :: String -> Map String, String -> p result
    getJSON: (name, query-string) ->
        @[name].abort! if !!@[name]
        new Promise (res, rej) ~>
            @[name] = $.getJSON \/apis/queryTypes/mongodb/connections, query-string
                ..done -> res it
                ..fail ({response-text}) -> rej response-text

    # load-database :: String -> p [Database]
    load-databases: (connection-name) ->
        (@getJSON \databases-request, {connection-name}).then ({databases or []}) -> databases

    # load-collections :: String -> String -> p [Collection]
    load-collections: (connection-name, database) ->
         (@getJSON \collections-request, {connection-name, database}).then ({collections or []}) -> collections |> map -> label: it, value: it

    # component-did-mount :: a -> Void
    component-did-mount: !->
        ($.getJSON \/apis/queryTypes/mongodb/connections, '') .done ({connections or []}) ~> @set-state {connections}

        # load databases & collections if the connection-name is defined
        if !!@props.data-source-cue?.connection-name and (@props.data-source-cue.connection-name.index-of '- (') != 0
            {connection-name, database} = @props.data-source-cue
            @set-state {loading-databases: true, loading-collections: true}
            databases <~ (@load-databases connection-name).then
            @set-state {loading-databases: false, databases}
            collections <~ (@load-collections connection-name, database).then
            @set-state {loading-collections: false, collections}

    # component-will-receive-props :: Props -> Void
    component-will-receive-props: (props) !->

        prev-data-source-cue = @props.data-source-cue
        data-source-cue = props.data-source-cue

        load-collections = (connection-name, database) ~>
            @set-state {loading-collections: true}
            collections <~ (@load-collections connection-name, database).then
            @set-state {loading-collections: false, collections}
            if !(data-source-cue.collection in map (.value), collections)
                @update-props props, {collection : collections.0.value}

        # loading databases because connection-name changed
        if prev-data-source-cue?.connection-name != data-source-cue?.connection-name
            @set-state {loading-databases: true, loading-collections: true}
            databases <~ (@load-databases data-source-cue.connection-name).then
            @set-state {loading-databases: false, databases}

            # keep the current database if its there in the list of loaded databases
            # othewise pick the first one
            database = 
                | data-source-cue.database in databases => data-source-cue.database
                | _ => databases.0
            @update-props props, {database}
            
            # loading collections because connection-name changed but database did not
            # Note: change in database prop will trigger this function again causing collections to reload
            if prev-data-source-cue?.database == database
                load-collections data-source-cue.connection-name, database

        # loading collections because database changed
        else if prev-data-source-cue?.database != data-source-cue?.database
            load-collections data-source-cue.connection-name, data-source-cue.database
