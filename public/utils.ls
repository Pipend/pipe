# the first require is used by browserify to import the LiveScript module
# the second require is defined in the LiveScript module and exports the object
require \LiveScript
{compile} = require \LiveScript

# the first require is used by browserify to import the prelude-ls module
# the second require is defined in the prelude-ls module and exports the object
require \prelude-ls
{keys, map, Str, floor} = require \prelude-ls

# this method differs from /utils.ls::compile-and-execute-livescript,
# it uses the eval function to execute javascript since the "vm" module is unavailable on client-side
module.exports.compile-and-execute-livescript = (livescript-code, context)->

    die = (err)->
        [err, null]

    try 
        js = compile do 
            """
            f = ({#{keys context |> Str.join \,}}:context)->
            #{livescript-code |> Str.lines |> map (-> "    " + it) |> Str.unlines}
            f context
            """
            {bare: true}
    catch err
        return die "livescript transpilation error: #{err.to-string!}"

    try 
        result = eval js
    catch err
        return die "javascript runtime error: #{err.to-string!}"

    [null, result]


module.exports.object-id-from-date = (date) ->
    ((floor date.getTime! / 1000).to-string 16) + "0000000000000000"

module.exports.date-from-object-id = (object-id) ->
    new Date (parse-int (object-id.substring 0, 8), 16) * 1000
