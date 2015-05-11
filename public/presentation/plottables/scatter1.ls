{map, floor} = require \prelude-ls

ξ = (h, f, g) --> (x) -> (f x) `h` (g x)

module.exports = ({Plottable, plot-chart, d3, nv}:params) -> 
    scatter = (require \./scatter.ls) params
    new Plottable do
        scatter.plotter
        scatter.options
        scatter.continuations
        (data, options) -> data |> (map (d) -> {} <<< d <<< {
            key: (if !!options.key then options.key else ξ (-> "#{&0}_#{&1}_#{floor Math.random!*10000}"), options.x, options.y) d
            values: [d]
        }) >> ((fdata) -> scatter.projection fdata, options)