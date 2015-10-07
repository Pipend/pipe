{camelize, map, reject} = require \prelude-ls
{create-factory, DOM:{button, div, span}}:React = require \react
OpsManager = create-factory require \./OpsManager.ls

module.exports = React.create-class do

    display-name: \OpsRoute

    # get-default-props :: a -> Props
    get-default-props: -> {}

    # render :: a -> ReactElement
    render: ->
        div do 
            class-name: \ops-route
            OpsManager do 
                ops: @state.ops |> map ({op-id, op-info, parent-op-id, creation-time}:x) ~>
                    console.log \op, (JSON.stringify x, null, 4)
                    {document, url}? = op-info
                    {branch-id, data-source-cue, query-id, query-title}? = document
                    op-id: op-id
                    parent-op-id: parent-op-id
                    query-type: data-source-cue?.query-type ? "N/A"
                    query-title: query-title ? "N/A"
                    query-url: "branches/#{branch-id}/queries/#{query-id}"
                    api-call: url
                    creation-time: creation-time
                columns: @state.columns
                sort-column: @state.sort-column
                sort-order: @state.sort-order
                on-sort-column-change: (sort-column) ~> @set-state {sort-column}
                on-sort-order-change: (sort-order) ~> @set-state {sort-order}
                on-terminate: ({op-id}) ~> $.get "/apis/ops/#{op-id}/cancel"

    # get-initial-state :: a -> UIState
    get-initial-state: ->
        ops: [] # [Op] 
        sort-column: camelize \creation-time
        sort-order: -1
        columns: map camelize, <[op-id parent-op-id query-type query-title query-url api-url creation-time]>

    # component-did-mount :: a -> Void
    component-did-mount: !->
        @socket = (require \socket.io-client).connect force-new: true
            ..on \ops, (ops) ~> @set-state {ops}

    # component-will-unmount :: a -> Void
    component-will-unmount: !->
        if !!@socket
            @socket.disconnect!