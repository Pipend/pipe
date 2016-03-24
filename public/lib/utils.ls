# the first require is used by browserify to import the prelude-ls module
# the second require is defined in the prelude-ls module and exports the object
require \prelude-ls
{keys, map, concat-map} = require \prelude-ls

# this method differs from /utils.ls::compile-and-execute-livescript,
# it uses the eval function to execute javascript since the "vm" module is unavailable on client-side

# cancel-event :: Event -> Void
export cancel-event = (e) !->
    e.prevent-default!
    e.stop-propagation!

# get-all-keys-recursively :: (k -> v -> Bool) -> Map k, v -> [String]
export get-all-keys-recursively = (filter-function, object) -->
    keys object |> concat-map (key) -> 
        return [] if !filter-function key, object[key]
        return [key] ++ (get-all-keys-recursively filter-function, object[key])  if typeof object[key] == \object
        [key]