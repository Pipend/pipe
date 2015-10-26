{Promise} = require \bluebird

# nvd3 requires d3 to be in global space
window.d3 = require \d3
require \nvd3 

# the first require is used by browserify to import the livescript module
# the second require is defined in the livescript module and exports the object
require \livescript
{compile} = require \livescript

# the first require is used by browserify to import the prelude-ls module
# the second require is defined in the prelude-ls module and exports the object
require \prelude-ls
{keys, map, Str} = require \prelude-ls

transformation-context = require \../transformation/context.ls
presentation-context = require \../presentation/context.ls
{compile-and-execute-livescript, compile-and-execute-javascript, compile-and-execute-babel} = require \../utils.ls

<- window.add-event-listener \load

# String (element id) -> Hash -> Promise String (compiled code)
compile = (element-id, imports) ->
    resolve, reject <- new Promise _
    element = document.get-element-by-id element-id
    code = element .innerHTML.replace /\t/g, " "

    compile_ = switch element.get-attribute \data-transpilation
    | 'livescript' => compile-and-execute-livescript 
    | 'javascript' => compile-and-execute-javascript
    | 'babel' => compile-and-execute-babel

    [error, code-function] = compile_ "(#code\n)", {} <<< imports
    return reject error if !!error
    resolve code-function

# query-result & parameters are in global space (rendered by server)

new Promise (resolve, reject) ->
    transformation-function <- (compile 'transformation', {} <<< transformation-context! <<< parameters <<< (require \prelude-ls)).then _
    presentation-function <- (compile 'presentation', {d3, $} <<< transformation-context! <<< presentation-context! <<< parameters <<< (require \prelude-ls)).then _

    try
        transformed-result = transformation-function query-result

        $presentation = document.get-elements-by-class-name \presentation .0

        # if transformation returns a stream then listen to it and update the presentation
        if \Function == typeof! transformed-result.subscribe    
            transformed-result.subscribe (e) -> presentation-function $presentation, e

        # otherwise invoke the presentation function once with the JSON returned from transformation
        else
            presentation-function $presentation, transformed-result
    catch ex
        reject ex

    resolve "done!"

.then ->
    console.log it
.catch ->
    console.error it
    document.get-elements-by-class-name \presentation .0 .innerHTML = "<div style='color: red'>" + it.to-string! + "</div>"