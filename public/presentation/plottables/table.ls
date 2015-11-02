{id, filter, Obj, obj-to-pairs, sort-by} = require \prelude-ls

module.exports = ({Plottable, nv, plot-chart, plot}) -> new Plottable do 
    (view, result, {cell, cells, cols-order, cols}, continuation) !--> 

        cols = cols ? do -> result.0 |> Obj.keys |> (filter (.index-of \$) >> (!= 0)) |> sort-by (-> b = (cols-order.index-of it); if b == -1 then Infinity else b )
        
        #todo: don't do this if the table is already present
        $table = d3.select view .append \pre .append \table .attr \class, \plottable
        $table.append \thead .append \tr
        $table.append \tbody

        $table.select 'thead tr' .select-all \td .data cols
            ..enter!
                .append \td
            ..exit!.remove!
            ..text id
            ..attr \class, id

        
        $table.select \tbody .select-all \tr .data result
            ..enter!
                .append \tr
                .attr \style, (.$style)
            ..exit!.remove!
            ..select-all \td .data obj-to-pairs >> (filter ([k]) -> (cols.index-of k) > -1) >> (sort-by (([k]) -> cols.index-of k))
                ..enter!
                    .append \td
                ..exit!.remove!
                ..each ([key, value]) -> 
                    f = cells[key]
                    if !!f
                        (plot f) @, value
                    else
                        cell @, key, value

        <- continuation $table, result

    {
        cell: (view, key, value) -->
            d3.select view
                .text value
                .attr \class, key
        # Map String (column name) (View -> result -> IO ())
        cells: {}
        cols-order: []
        cols: null
    }