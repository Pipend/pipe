{map, id, filter, Obj, pairs-to-obj} = require \prelude-ls

module.exports = ({Plottable, d3, plot-chart, nv}) -> new Plottable do
    (view, result, {traits, category}, continuation) !->

        if !traits
            traits := Obj.keys result.0

        if !category
            category := -> "any-category"


        width = view.client-width
        padding = 10
        n = traits.length
        size = (width - (n * padding)) / n

        x = d3.scale.linear!.range [padding / 2, size - padding / 2]
        y = d3.scale.linear!.range [size - padding / 2, padding / 2]

        x-axis = d3.svg.axis!
            .scale x
            .orient \bottom
            .ticks 5
            .tick-size size * n

        y-axis = d3.svg.axis!
            .scale y
            .orient \left
            .ticks 5
            .tick-size -1 * size * n


        color = d3.scale.category10!


        domain-by-trait = traits |> (map (t) -> [t, (d3.extent result, (d) -> d[t])]) >> pairs-to-obj


        cross = (a, b) -->
            [{i, j, x: a[i], y: b[j] } for i in [0 to a.length - 1] for j in [0 to b.length - 1]]


        plot = (p) ->
            cell = d3.select this

            x.domain domain-by-trait[p.x]
            y.domain domain-by-trait[p.y]

            cell.append \rect
                .attr \class, \frame
                .attr \x, padding / 2
                .attr \y, padding / 2
                .attr \width, size - padding
                .attr \height, size - padding

            cell.select-all \circle
                .data result
                .enter!.append \circle
                .attr "cx", (d) -> x d[p.x]
                .attr "cy", (d) -> y d[p.y]
                .attr "r", 3
                .style "fill", (d) -> color (category d)


        svg = d3.select view .append \svg
            .attr \class, \correlation-matrix
            .attr \width, size * n + padding
            .attr \height, size * n + padding
            .append \g
            .attr \transform, "translate(" + padding + "," + padding / 2 + ")"

        svg.select-all \.x.axis
            .data traits
            .enter!.append \g
            .attr \class, 'x axis'
            .attr \transform, (d, i) -> "translate(" + (n - i - 1) * size + ",0)"
            .each (d) -> 
                x.domain domain-by-trait[d]
                d3.select this .call x-axis

        svg.select-all \.y.axis
            .data traits
            .enter!.append \g
            .attr \class, 'y axis'
            .attr \transform, (d, i) -> "translate(0," + i * size + ")"
            .each (d) ->
                y.domain domain-by-trait[d]
                d3.select this .call y-axis


        cell = svg.select-all \.cell
            .data (cross traits, traits)
            .enter!.append \g
            .attr "class", "cell"
            .attr "transform", (d) -> "translate(" + (n - d.i - 1) * size + "," + d.j * size + ")"
            .each plot

        cell
            .filter (d) -> d.i == d.j
            .append \text
            .attr \x, padding
            .attr \y, padding
            .attr \dy, \.71em
            .text (.x)

        brush-cell = null

        brushstart = (p) ->
            if brush-cell !== this
              d3.select brush-cell .call brush.clear!
              x.domain domain-by-trait[p.x]
              y.domain domain-by-trait[p.y]
              brush-cell = this

        brushmove = (p) ->
            e = brush.extent!
            svg.select-all \circle .classed \hidden, (d) ->
                e[0][0] > d[p.x] or d[p.x] > e[1][0]
                or e[0][1] > d[p.y] or d[p.y] > e[1][1]

        brushend = ->
            if brush.empty!
                svg.select-all \.hidden .classed \hidden, false

        brush = d3.svg.brush!
            .x x
            .y y
            .on \brushstart, brushstart
            .on \brush, brushmove
            .on \brushend, brushend

        cell.call brush