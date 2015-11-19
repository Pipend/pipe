{Obj, Str, id, any, average, concat-map, drop, each, filter, find, foldr1, foldl, map, maximum, minimum, obj-to-pairs, pairs-to-obj, sort, sum, tail, take, unique} = require \prelude-ls
{rextend} = require \./../plottables/_utils.ls


Reactive = {}

Reactive.Plottable = class Plottable
    (@calculator, @plotter, @options = {}, @continuations = ((..., callback) -> callback null), @projection = id) ->
    _cplotter: (result) ~>
        cresult = @calculator (@projection result), @options
        (change, meta, view) ~~>
            @plotter change, meta, view, cresult, @options, @continuations
    _plotter: (change, meta, view, result) ~>
        @plotter change, meta, view, (@projection result), @options, @continuations


# f :: Meta -> View -> result -> {}:options -> IO ()
# f -> Reactive.Plottable Meta View result options
Reactive.plottable = (f) ->
    new Reactive.Plottable do
        id  # calculator
        (change, meta, view, result, options) !-->
            f change, meta, view, result, options
            

# Attaches options to a Reactive.Plottable
Reactive.with-options = (p, o) ->
  new Reactive.Plottable do
    p.calculator
    p.plotter
    ({} `rextend` p.options) `rextend` o
    p.continuations
    p.projection
 
Reactive.amore = (p, c) ->
  new Reactive.Plottable do
    p.calculator
    p.plotter
    {} `rextend` p.options
    c
    p.projection
 
Reactive.more = (p, c) ->
  new Reactive.Plottable do
    p.calculator
    p.plotter
    {} `rextend` p.options
    (...init, callback) -> 
      try 
        c ...init
      catch ex
        return callback ex
      callback null
    p.projection
 
# projects the data of a Reactive.Plottable with f
Reactive.project = (f, p) -->
  new Reactive.Plottable do
    p.calculator
    p.plotter
    {} `rextend` p.options
    p.continuations
    (data, options) -> 
        fdata = f data, options
        p.projection fdata, options



# Reactive.Plottable -> Change -> Meta -> View -> result -> IO ()
xplot = (p, result, change, meta, view) -->
    #p._plotter meta, view, result  # old version
    cplot (p._cplotter result), change, meta, view

# (Change -> Meta -> View -> IO ()) -> Meta -> View -> IO ()
cplot = (cplotter, change, meta, view) -->
    cplotter change, meta, view



Reactive <<< {xplot, cplot}

exports_ = {
    Reactive, d3
}

plottables = {
    table: (require \./table.ls) exports_
} <<< (require \./layout.ls) exports_

Reactive <<< plottables

module.exports = Reactive