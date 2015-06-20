base62 = require \base62

# the first require is used by browserify to import the LiveScript module
# the second require is defined in the LiveScript module and exports the object
require \LiveScript
{compile} = require \LiveScript

# the first require is used by browserify to import the prelude-ls module
# the second require is defined in the prelude-ls module and exports the object
require \prelude-ls
{all, any, keys, is-type, keys, map, Str, floor, concat-map} = require \prelude-ls

# this method differs from /utils.ls::compile-and-execute-livescript,
# it uses the eval function to execute javascript since the "vm" module is unavailable on client-side


export cancel-event = (e) ->
    e.prevent-default!
    e.stop-propagation!
    # false

export compile-and-execute-livescript = (livescript-code, context) ->

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

export date-from-object-id = (object-id) -> new Date (parse-int (object-id.substring 0, 8), 16) * 1000

# two objects are equal if they have the same keys & values
export is-equal-to-object = (o1, o2) ->
    return o1 == o2 if <[Boolan Number String]> |> any -> is-type it, o1
    return false if (typeof o1 == \undefined || o1 == null) || (typeof o2 == \undefined || o2 == null)
    (keys o1) |> all (key) ->
        if is-type \Object o1[key]
            o1[key] `is-equal-to-object` o2[key]
        else if is-type \Array o1[key]
            return false if o1.length != o2.length
            [1 to o1.length] |> -> all o1[it] `is-equal-to-object` o2[it]
        else
            o1[key] == o2[key]


# get-all-keys-recursively :: (k -> v -> Bool) -> Map k, v -> [String]
export get-all-keys-recursively = (filter-function, object) -->
    keys object |> concat-map (key) -> 
        return [] if !filter-function key, object[key]
        return [key] ++ (get-all-keys-recursively filter-function, object[key])  if typeof object[key] == \object
        [key]

export object-id-from-date = (date) -> ((floor date.getTime! / 1000).to-string 16) + "0000000000000000"

export generate-uid = -> base62.encode Date.now!
