{Promise} = require \bluebird

# the first require is used by browserify to import the prelude-ls module
# the second require is defined in the prelude-ls module and exports the object
require \prelude-ls
{keys, map, pairs-to-obj, Str} = require \prelude-ls

{compile-transformation, compile-presentation}:web-client = (require \pipe-web-client) end-point: "http://#{window.location.host}"

<- window.add-event-listener \load

{transformation, presentation} = <[transformation presentation]>
    |> map -> [it, (document.get-element-by-id it .innerHTML .replace /\t/g, " ")]
    |> pairs-to-obj

view = document.get-elements-by-class-name \presentation .0

new Promise (resolve, reject) ->
    transformation-function <- compile-transformation transformation, window.transpilation.transformation .then _
    presentation-function <- compile-presentation presentation, window.transpilation.presentation .then _

    try
        transformed-result = transformation-function query-result, compiled-parameters

        # if transformation returns a stream then listen to it and update the presentation
        if \Function == typeof! transformed-result.subscribe    
            transformed-result.subscribe (e) -> presentation-function view, e, compiled-parameters

        # otherwise invoke the presentation function once with the JSON returned from transformation
        else
            presentation-function view, transformed-result, compiled-parameters

    catch ex
        reject ex

    resolve "done!"

.catch ->
    view .innerHTML = "<div style='color: red'>" + it.to-string! + "</div>"