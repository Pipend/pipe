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
{compile-and-execute-livescript} = require \../utils.ls

<- window.add-event-listener \load

# query-result & parameters existing in global space (rendered by server)
transformation = (document.get-element-by-id \transformation .innerHTML).replace /\t/g, " "
[err, transformation-function] = compile-and-execute-livescript "(#transformation\n)", {} <<< transformation-context! <<< parameters <<< (require \prelude-ls)
return console.log err if !!err

presentation = (document.get-element-by-id \presentation .innerHTML).replace /\t/g, " "
[err, presentation-function] = compile-and-execute-livescript "(#presentation\n)", {d3, $} <<< transformation-context! <<< presentation-context! <<< parameters <<< (require \prelude-ls)
return console.log err if !!err

transformed-result = transformation-function query-result

$presentation = document.get-elements-by-class-name \presentation .0

# if transformation returns a stream then listen to it and update the presentation
if \Function == typeof! transformed-result.subscribe    
    transformed-result.subscribe (e) -> presentation-function $presentation, e

# otherwise invoke the presentation function once with the JSON returned from transformation
else
    presentation-function $presentation, transformed-result