{id, map, filter, Obj, obj-to-pairs, sort-by} = require \prelude-ls

module.exports = ({{Plottable, xplot}:Reactive, d3}) ->


    new Reactive.Plottable do 
        (result, {cells, cols, iden, cols-order}:options) ->
            cols = cols ? do -> result.0 |> Obj.keys |> (filter (.index-of \$) >> (!= 0)) |> sort-by (-> b = (cols-order.index-of it); if b == -1 then Infinity else b )
            result 
            |> map (r) ->
                iden: iden r
                cols: do ->
                    cols |> map (c) ->
                        p = cells[iden r[c]] ? Reactive.plottable (_, meta, view, result, options) -> view.innerHTML = result
                        xplot p, r[c]
                    
            #result
        
        ({change}:change_, meta, view, result, {iden}:options, continuation) !-->
            
            
            d3.select view .select-all \div .data result
                ..enter!
                    ..append \div .on \click, (result-item) -> 
                        change 'highlight', result-item.iden, (-> !it)
                ..attr \style, (result-item) -> "background-color: #{if meta['highlight']?[result-item.iden] then 'green' else 'blue'}"
                ..select-all \span.col .data (.cols)
                    ..enter!
                        ..append \span .attr \class, \col
                    ..each (d) ->
                        d change_, meta, @
                ..exit! .remove!
                
        {
            #iden: id
            cols-order: []
            cols: null
            iden: (.id)
            cells: 
                value: Reactive.plottable (_, meta, view, result, options) ->
                    view.innerHTML = result
        }
