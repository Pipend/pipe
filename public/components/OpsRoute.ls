{camelize, map, reject, sort-by} = require \prelude-ls
{create-factory, DOM:{a, button, div, span}}:React = require \react
create-fragment = require \react-addons-create-fragment
SimpleButton = create-factory require \./SimpleButton.ls
Table = create-factory require \./Table.ls

module.exports = React.create-class do

    display-name: \OpsRoute

    # get-default-props :: a -> Props
    get-default-props: -> {}

    # render :: a -> ReactElement
    render: ->
        div do 
            class-name: \ops-route
            Table do 
                columns:
                    * label: \Title
                    * label: \Type
                    * label: \URL
                      sortable: false
                      width: 35
                      render-cell: ({label, value}) ~> a href: value, label
                    * label: 'Created on'
                    * label: \CPU
                    * label: \Actions
                      sortable: false
                      render-cell: ({op-id, branch-id, query-id}:cell) ~>
                        create-fragment do
                            left: SimpleButton do
                                color: \grey
                                style: margin-left: 2px
                                on-click: ~> window.open "branches/#{branch-id}/queries/#{query-id}", \_blank
                                'Edit query'
                            right: SimpleButton do 
                                color: \red
                                style: margin-left: 8px
                                on-click: ~> $.get "/apis/ops/#{op-id}/cancel"
                                \Terminate
                    ...
                rows: @state.ops 
                    |> map ({op-id, op-info, parent-op-id, cpu, creation-time}) ~>

                        # extract more information from the op object
                        {url}? = op-info
                        {branch-id, data-source-cue, query-id, query-title}? = op-info.document

                        seconds = Math.floor cpu / 1000

                        cells = 
                            * value: query-title
                            * value: data-source-cue.query-type
                            * value: url
                            * label: new Date creation-time .to-JSON!
                              value: creation-time
                            * label: "#{seconds} second#{if seconds > 1 then 's' else ''}"
                              value: cpu
                            * op-id: op-id
                              branch-id: branch-id
                              query-id: query-id
                            ...

                        row-id: op-id

                        # use value property as the label (if label is not specified)
                        cells: cells |> map -> 
                            {} <<< it <<< label: (it?.label ? it.value)

                    |> sort-by ~> it.cells[@state.sort-column].value * @state.sort-direction

                # index of the column to sort by
                sort-column: @state.sort-column

                # +1 for ascending and -1 for descending
                sort-direction: @state.sort-direction

                on-change: (props) ~> @set-state props

    # get-initial-state :: a -> UIState
    get-initial-state: ->
        ops: []
        sort-column: 0
        sort-direction: -1

    # component-did-mount :: a -> Void
    component-did-mount: !->
        @socket = (require \socket.io-client).connect force-new: true
            ..on \ops, (ops) ~> @set-state {ops}

    # component-will-unmount :: a -> Void
    component-will-unmount: !->
        if !!@socket
            @socket.disconnect!