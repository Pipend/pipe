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
                ops: @state.ops |> map ({op-id, parent-op-id, op-info, local-creation-time, creation-time}) ~>
                    {document, url}? = op-info
                    {branch-id, data-source-cue, query-id, query-title}? = document
                    op-id: op-id
                    parent-op-id: parent-op-id
                    query-type: data-source-cue?.query-type ? "N/A"
                    query-title: query-title ? "N/A"
                    query-url: "branches/#{branch-id}/queries/#{query-id}"
                    api-call: url
                    creation-time: creation-time
                    cpu-time: @state.server-time - creation-time
                columns: @state.columns
                sort-column: @state.sort-column
                sort-order: @state.sort-order
                on-sort-column-change: (sort-column) ~> @set-state {sort-column}
                on-sort-order-change: (sort-order) ~> @set-state {sort-order}
                on-terminate: ({op-id}) ~> $.get "/apis/ops/#{op-id}/cancel"

    # get-initial-state :: a -> UIState
    get-initial-state: ->
        ops: [] # [Op] 
        server-time: 0
        sort-column: camelize \creation-time
        sort-order: -1
        columns: map camelize, <[op-id parent-op-id query-type query-title query-url api-url creation-time cpu-time]>

    # component-did-mount :: a -> Void
    component-did-mount: !->
        @socket = (require \socket.io-client).connect force-new: true
            ..on \running-ops, ([server-time, ops]) ~> @set-state server-time: server-time, ops: ops ? []
            ..on \op-started, ([server-time, op]) ~> @set-state server-time: server-time, ops: @state.ops ++ [op]
            ..on \op-ended, ([server-time, op-id, status]) ~> @set-state server-time: server-time, ops: (@state.ops |> reject -> it.op-id == op-id or it.parent-op-id == op-id)
            ..on \sync, (server-time) ~> @set-state {server-time}
        set-interval do 
            ~> @force-update!
            1000

    # component-will-unmount :: a -> Void
    component-will-unmount: !->
        if !!@socket
            @socket.disconnect!