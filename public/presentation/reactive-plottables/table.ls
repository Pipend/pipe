{id, map, filter, Obj, obj-to-pairs, sort-by} = require \prelude-ls

module.exports = ({{Plottable, xplot}:Reactive, d3}) -> new Reactive.Plottable do 
    (result, {cells, cell, cols, iden, cols-order}:options) ->
        cols = cols ? do -> result.0 |> Obj.keys |> (filter (.index-of \$) >> (!= 0)) |> sort-by (-> b = (cols-order.index-of it); if b == -1 then Infinity else b )
        result 
        |> map (r) ->
            iden: iden r
            data: r
            cols: do ->
                cols |> map (c) ->
                    p = cells[iden r[c]] ? cell
                    xplot p, r[c]

                
        #result
        
    ({change, toggle, fx, dfx}:change_, meta, view, result, {cols, row-style}:options, continuation) !-->
            
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
                    ..on 'click', -> toggle 'select', it.iden
                    ..on 'mouseover', -> fx 'highlight', it.iden
                    ..on 'mouseout', -> dfx 'highlight', it.iden
            
            ..attr 'style', -> row-style it.iden, meta[it.iden], it.data
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
                view.innerHTML = result
        cells: {}
        row-style: (iden, meta, data) -> ''
    }
