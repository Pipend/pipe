{id, map, filter, reject, group-by, Obj, obj-to-pairs, sort-by} = require \prelude-ls
{fold-obj-to-list} = (require \./../../transformation/context.ls)!

module.exports = ({{Plottable, xplot}:Reactive, d3}) -> new Reactive.Plottable do 
    (result, {key, sorter, cells, cell, cols, iden, cols-order}:options) ->
        cols = cols ? do -> result.0 |> Obj.keys |> (filter (.index-of \$) >> (!= 0)) |> sort-by (-> b = (cols-order.index-of it); if b == -1 then Infinity else b )
        result 
        |> group-by key.f
        |> fold-obj-to-list (k, r) ->
            iden: k
            data: r
            cols: do ->
                cols |> map (c) ->
                    p = cells[c] ? cell
                    xplot p, (r.map -> it[c])
            sort-key: sorter r
        |> sort-by (.sort-key)
                
        #result
        
    ({change, toggle, fx, dfx, is-highlighted, is-selected}:change_, meta, view, result, {key, cols, row-style}:options, continuation) !-->
            
        cols = cols ? do -> result.0 |> map (.iden)


        #todo: don't do this if the table is already present
        $table = d3.select view .select-all 'pre' .data [cols] 
            ..enter! 
                ..append \pre 
                    ..append \table .attr \class, \plottable
                        ..append \thead .append \tr
                        ..append \tbody

        $table.select 'thead tr' .select-all \td .data cols
            ..enter!
                .append \td
            ..exit!.remove!
            ..text id
            ..attr \class, id

        
        $table.select \tbody .select-all \tr .data result
            ..enter!
                ..append \tr
                    # ..attr \style, (.$style) TODO:
                    ..on 'click', -> toggle 'select', key.iden, it.iden
                    ..on 'mouseover', -> fx 'highlight', key.iden, it.iden
                    ..on 'mouseout', -> dfx 'highlight', key.iden, it.iden
            
            ..attr 'style', -> row-style { 
                highlight: (is-highlighted key.iden, it.iden) 
                select: (is-selected key.iden, it.iden) 
            }
            ..exit!.remove!
            ..select-all \td .data (({cols, iden}) -> cols |> map (col) -> {col, iden})
                ..enter!
                    .append \td
                ..exit!.remove!
                ..each ({col, iden}) -> # col :: Plottable
                    col change_, meta[iden], @

        <- continuation $table, result

                
    {
        cols-order: []
        cols: null
        iden: (.id)
        cell: Reactive.plottable (_, meta, view, result, options) ->
                view.innerHTML = result.0
        cells: {}
        row-style: (iden, meta, data) -> ''

        # table is 1-dimensional
        key:
            f: (.key)
            iden: 'key'
        sorter: (ds) -> 1
    }
