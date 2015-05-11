module.exports = ({Plottable, nv, d3, plot-chart}:params) -> 
    timeseries = (require \./timeseries.ls) params
    new Plottable do
        timeseries.plotter
        timeseries.options
        timeseries.continuations
        (data, options) -> [{key: "", values: data}] |> ((fdata) -> timeseries.projection fdata, options)