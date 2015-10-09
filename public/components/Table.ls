{camelize, dasherize, filter, find, id, map, keys, obj-to-pairs, pairs-to-obj, reject, sort-by, Str, sum, values} = require \prelude-ls
{DOM:{a, div, span}}:React = require \react

module.exports = React.create-class do

    display-name: \Table

    # get-default-props :: a -> Props
    get-default-props: ->
        columns: [] # [Column] where Column :: {label: String, width: Int}
        locked-rows: [] # [String]
        rows: [] # [Row] where Row :: {row-id: String, cells: [Cell]}, Cell :: a | {label :: String, value :: a}
        sort-column: 0
        sort-direction: 1
        # on-change :: Props -> Void
        on-change: (props) !-> 

    # render :: a -> ReactElement
    render: ->

        {columns, locked-rows, rows, sort-column, sort-direction} = @props

        known-widths = columns 
            |> filter -> !!it?.width
            |> map (.width)
            
        distributed-width = (100 - sum known-widths) / (columns.length - known-widths.length)

        # TABLE
        div class-name: \table,

            # TABLE HEAD
            div class-name: \head,
                [0 til columns.length] |> map (i) ~>

                    {label, width}? = columns[i]

                    # COLUMN NAME (toggle sort-column / sort-direction on click)
                    div do 
                        key: label
                        class-name: if i == sort-column then "selected #{if sort-direction == 1 then "up" else "down"}" else ""
                        style: width: "#{width ? distributed-width}%"
                        on-click: ~>
                            @props.on-change do
                                sort-column: i
                                sort-direction: sort-direction * (if i == sort-column then -1 else 1)
                        label

            # TABLE BODY
            div class-name: \body, 
                [0 til rows.length] |> map (i) ~>
                    
                    {row-id, cells} = rows[i]

                    # render-cell :: Int -> Cell -> ReactElement
                    render-cell = (.label)

                    # is-locked :: Boolean
                    is-locked = !!(find (== row-id), locked-rows)

                    # ROW (lock / unlock on click)                    
                    div do 
                        key: row-id
                        class-name: if is-locked then \locked else ''
                        on-click: ~> 
                            @props.on-change do
                                locked-rows: switch
                                    | is-locked => reject (== row-id), locked-rows
                                    | _ => [row-id] ++ locked-rows

                        # CELLS                        
                        [0 til cells.length] |> map (j) ~>
                            div do 
                                style: width: "#{columns[j]?.width ? distributed-width}%"
                                (columns[j]?.render-cell ? render-cell) cells[j]