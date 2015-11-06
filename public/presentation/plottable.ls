{Obj, Str, id, any, average, concat-map, drop, each, filter, find, foldr1, foldl, map, maximum, minimum, obj-to-pairs, pairs-to-obj, sort, sum, tail, take, unique} = require \prelude-ls

{rextend} = require \./plottables/_utils.ls

module.exports = (fmap) ->
  # Plottable is a monad, run it by plot funciton
  class Plottable
    (@plotter, @options = {}, @continuations = ((..., callback) -> callback null), @projection = id) ->
    _plotter: (view, result) ~>
        @plotter view, (fmap @projection, result), @options, @continuations

  # f :: View -> result -> {}:options -> IO ()
  # f -> Plottable View result options
  plottable = (f) ->
      new Plottable (view, result, options) !-->
          f view, result, options

  # Runs a Plottable
  plot = (p, view, result) -->
      p._plotter view, result 

  # Attaches options to a Plottable
  with-options = (p, o) ->
    new Plottable do
      p.plotter
      ({} `rextend` p.options) `rextend` o
      p.continuations
      p.projection
    
  acompose = (f, g) --> (chart, callback) ->
    err, fchart <- f chart
    return callback err, null if !!err
    g fchart, callback
   
  amore = (p, c) ->
    new Plottable do
      p.plotter
      {} `rextend` p.options
      c
      p.projection
   
  more = (p, c) ->
    new Plottable do
      p.plotter
      {} `rextend` p.options
      (...init, callback) -> 
        try 
          c ...init
        catch ex
          return callback ex
        callback null
      p.projection
   
  # projects the data of a Plottable with f
  project = (f, p) -->
    new Plottable do
      p.plotter
      {} `rextend` p.options
      p.continuations
      (data, options) -> 
          fdata = f data, options
          p.projection fdata, options


  {
    Plottable
    plottable
    plot
    with-options
    acompose
    amore
    more
    project
  }