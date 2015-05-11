module.exports = ({Plottable, nv, plot-chart}:params) -> 
    histogram = (require \./histogram.ls) params
    new Plottable do
        histogram.plotter
        histogram.options
        histogram.continuations
        (data, options) -> [{key: "", values: data}] |> ((fdata) -> histogram.projection fdata, options)