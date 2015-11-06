{id, map, filter, Obj, obj-to-pairs, sort-by} = require \prelude-ls

module.exports = ({ReactivePlottable, plot, d3, unlift, fmap, traverse, is-highlighted}) -> new ReactivePlottable do 
    (view, lifted, {iden, cols-order, cols, cell, cells, change, fx, toggle}:options, continuation) !-->

        result = lifted |> map unlift
        cols = cols ? do -> result.0 |> Obj.keys |> (filter (.index-of \$) >> (!= 0)) |> sort-by (-> b = (cols-order.index-of it); if b == -1 then Infinity else b )


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

        
        $table.select \tbody .select-all \tr .data lifted
            ..enter!
                .append \tr
                # .attr \style, (.$style) TODO:
                .on 'click', toggle 'highlight'
            
            ..attr 'style', (lifted-item) -> "background-color: #{if is-highlighted lifted-item then 'green' else 'blue'}"
            ..exit!.remove!
            ..select-all \td .data traverse (obj-to-pairs >> (filter ([k]) -> (cols.index-of k) > -1) >> (sort-by (([k]) -> cols.index-of k)))
                ..enter!
                    .append \td
                ..exit!.remove!
                ..each (lifted-tuple) ->  # m [key, value]
                    tuple = unlift lifted-tuple
                    f = cells[tuple.0]
                    if !!f
                        (plot f) @, tuple.1
                    else
                        cell @, lifted-tuple

        <- continuation $table, result

    {
        cell: (view, lifted-tuple) -->
            tuple = unlift lifted-tuple
            d3.select view
                .text tuple.1
                .attr \class, tuple.0
        # Map String (column name) (View -> result -> IO ())
        cells: {}
        cols-order: []
        cols: null
        change: -> console.log \change
    }

    