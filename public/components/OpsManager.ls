{map, sort-by} = require \prelude-ls
{create-factory, DOM:{button, div, span}}:React = require \react

module.exports = React.create-class do

    display-name: \OpsManager

    # get-default-props :: a -> Props
    get-default-props: ->
        ops: [] # :: [Op], Where Op :: {op-id :: String, parent-op-id, query-type, query-titlex, url, creation-time, cpu-time}
        columns: [] # :: [String]
        on-sort-column-change: ((sort-column) ->)
        on-sort-order-change: ((sort-order) ->)
        sort-column: ""
        sort-order: 1

    # render :: a -> ReactElement
    render: ->

        #TABLE
        div do 
            class-name: \ops-manager

            # HEAD
            div do
                class-name: \head
                @props.columns |> map (column) ~>
                    span do 
                        key: column
                        class-name: if @props.sort-column == column then \sort else ""
                        on-click: ~> 
                            if @props.sort-column != column
                                @props.on-sort-column-change column
                            else
                                @props.on-sort-order-change -1 * @props.sort-order
                        column
                        

            # LIST OF TASKS
            div do
                class-name: \ops
                @props.ops 
                    |> sort-by ~> it[@props.sort-column] * @props.sort-order
                    |> map ({op-id}:op) ~>
                        div do 
                            key: op-id
                            class-name: \op,
                            @props.columns |> map (column) ~>
                                span do 
                                    key: column
                                    op[column] ? ""
                            button do
                                on-click: ~> @props.on-terminate op
                                \terminate

