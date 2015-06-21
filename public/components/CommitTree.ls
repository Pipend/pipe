$ = require \jquery-browserify
d3 = require \d3-browserify
{camelize, dasherize, filter, find, fold, group-by, map, Obj, obj-to-pairs, pairs-to-obj, sort-by, unique, unique-by, values} = require \prelude-ls
{DOM:{div}}:React = require \react

draw-commit-tree = (element, width, height, queries, tooltip-keys, tooltip-actions) -->

    d3-element = d3.select element

    create-commit-tree-json = (queries, {query-id, branch-id, selected}:query) -->

        children = queries 
            |> filter (.parent-id == query-id) 
            |> map (create-commit-tree-json queries)

        if (children |> filter (.branch-id == branch-id)).length == 0
            children.push [{query-id: null, branch-id, selected: false, children: null}]

        {children} <<< query

    # compute branch colors
    unique-branches = queries
        |> group-by (.branch-id)
        |> obj-to-pairs
        |> map (.0)
    color-scale = d3.scale.category10!.domain [0 til unique-branches.length]
    branch-colors = [0 til unique-branches.length]
        |> map (i) -> [unique-branches[i], color-scale i]
        |> pairs-to-obj

    tree = d3.layout.tree!.size [width, height]

    # compute tree nodes & links
    json = if !!queries and queries.length >  0 then create-commit-tree-json queries, queries.0 else []

    nodes = tree.nodes json
        |> map ({x, y}: node) ->
            node <<< {x: (y / height) * width, y: (x / width) * height}
    links = tree.links nodes

    # create the tooltip
    tooltip = d3-element .select \.tooltip

    if !!tooltip.empty!
        tooltip = d3-element .append \div .attr {class: \tooltip, style: \display:none}
            ..append \div .attr \class, \handle
            ..append \div .attr \class, \container
                ..append \div .attr \class, \rows
                ..append \div .attr \class, \controls                 
            ..append \div .attr \class, \handle .attr \style, \display:none

    if !!tooltip-actions
        tooltip .select \.controls .select-all \button .data tooltip-actions
            ..enter! .append \button
            ..text ({label}) -> label 
            .on \click, ({on-click}) -> on-click (d3.select \circle.highlight .datum!)
            ..exit!.remove!

    # plot the tree
    svg = d3-element .select \svg
    svg = d3-element.append \svg if !!svg.empty! 
    svg .attr \width, width .attr \height, height 
        ..select-all \path .data links
            ..enter!.append \path
            ..attr \data-branch-id, (({target: {branch-id}}) -> "#branch-id")
            .attr \d, ({source, target}) -> "M#{source.x} #{source.y} L#{target.x} #{target.y} Z"
            .attr \opacity, ({source, target}) -> if !!target?.children then 1 else 0
            .attr \stroke, (({source, target}) -> branch-colors[target.branch-id])
            ..exit!.remove!
        ..select-all \circle .data nodes
            ..enter!.append \circle
            ..attr \r, ({selected}) -> if !!selected then 16 else 8
            .attr \opacity, ({children}) -> if !!children then 1 else 0            
            .attr \fill, \white
            .attr \stroke, ({branch-id}) -> branch-colors[branch-id]
            .attr \transform, ({x, y}, i) -> "translate(#{(if i == 0 then 8 else 0) + x}, #y)"
            .on \click, ({branch-id, query-id}) -> window.open "/branch/#{branch-id}/#{query-id}", \_blank            
            .on \mouseover, ({x, y, branch-id, query-id}:query) ->                

                # update the tooltip data
                tooltip .attr \style, "" .select \.rows .select-all \div.row .data (query 
                        |> obj-to-pairs
                        |> map ([key, value]) -> [(tooltip-keys |> find -> it.key == key), value]
                        |> filter ([tooltip-key]) -> !!tooltip-key
                        |> map ([{name}, value]) ->  [name, value])
                    ..enter! .append \div .attr \class, \row
                        ..append \label
                        ..append \span                    
                    ..select \label .text (.0)
                    ..select \span .text (.1)
                    ..exit!.remove!                    

                circle = @
                circle-radius = parse-int (d3.select circle).attr \r
                
                # highlight the query node & branch                
                (d3.select circle).attr \class, \highlight .attr \fill, branch-colors[branch-id]
                d3.select-all "path[data-branch-id=#{branch-id}]" .attr \class, \highlight

                # position tooltip & the handle                               
                tooltip-width = tooltip.node!.offset-width
                tooltip-height = tooltip.node!.offset-height
                tooltip-x = if x + (tooltip-width / 2) > width then -2 * tooltip-width / 2 + width else x - tooltip-width / 2
                tooltip-x = if tooltip-x < 0 then 0 else tooltip-x
                handle-x = x - tooltip-x - 16
                handle-above = tooltip .select \.handle:first-child
                handle-below = tooltip .select \.handle:last-child                
                if y + tooltip-height > height
                    handle-above .attr \style, "display: none"
                    handle-below .attr \style, "left: #{handle-x}px;"
                    tooltip .attr \style, -> "left: #{tooltip-x}px; top: #{y - tooltip-height - circle-radius}px;"
                else                 
                    handle-above .attr \style, "left: #{handle-x}px;"
                    handle-below .attr \style, "display: none"
                    tooltip .attr \style, -> "left: #{tooltip-x}px; top: #{y + circle-radius}px;"                

                # hide the tooltip when the mouse moves out                 
                $ window .off \mouseover .on \mouseover, (e) ->                    
                    return if ($ e.original-event.target .parents \.tooltip .length == 1) || e.original-event.target == circle                    
                    $ window .off \mouseover
                    svg.select \circle.highlight .attr \fill, \white
                    svg.select-all \.highlight .attr \class, ""
                    tooltip .attr \style, "display: none"
            
            ..exit!.remove!

module.exports = React.create-class {

    render: ->
        div {ref: (camelize \commit-tree), class-name: \commit-tree}

    component-did-update: ->
        {width, height, queries or [], tooltip-keys or [], tooltip-actions or []}? = @.props
        console.log @.refs.commit-tree.get-DOM-node!
        draw-commit-tree @.refs.commit-tree.get-DOM-node!, width, height, queries, tooltip-keys, tooltip-actions

}




