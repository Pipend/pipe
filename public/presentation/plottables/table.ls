{id, filter, Obj, obj-to-pairs} = require \prelude-ls

module.exports = ({Plottable, nv, plot-chart}) -> new Plottable (view, result, options, continuation) !--> 

    cols = result.0 |> Obj.keys |> filter (.index-of \$ != 0)
    
    #todo: don't do this if the table is already present
    $table = d3.select view .append \pre .append \table
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
        ..select-all \td .data obj-to-pairs >> (filter ([k]) -> (cols.index-of k) > -1)
            ..enter!
                .append \td
            ..exit!.remove!
            ..text (.1)    
            ..attr \class, (.0)    

    <- continuation $table, result