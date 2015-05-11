$ = require \jquery-browserify

# nvd3 requires d3 to be in global space
window.d3 = require \d3-browserify
require \nvd3 

# the first require is used by browserify to import the LiveScript module
# the second require is defined in the LiveScript module and exports the object
require \LiveScript
{compile} = require \LiveScript

# the first require is used by browserify to import the prelude-ls module
# the second require is defined in the prelude-ls module and exports the object
require \prelude-ls
{keys, map, Str} = require \prelude-ls

transformation-context = require \../transformation/context.ls
presentation-context = require \../presentation/context.ls
{compile-and-execute-livescript} = require \../utils.ls

<- $
presentation = ($ \#presentation .html!).replace /\t/g, " "
[err, func] = compile-and-execute-livescript "(#presentation\n)", {d3, $} <<< transformation-context! <<< presentation-context! <<< parameters <<< (require \prelude-ls)
return console.log err if !!err

func do
    $ \.presentation .get 0
    transformed-result

