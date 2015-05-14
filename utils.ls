{compile} = require \LiveScript
{concat-map, keys, map} = require \prelude-ls
vm = require \vm

# all functions in this file are for use on server-side only (either by server.ls or query-types)

# this method differs from public/utils.ls::compile-and-execute-livescript, 
# it uses the native nodejs vm.run-in-new-context method to execute javascript instead of eval
export compile-and-execute-livescript = (livescript-code, context)->
    die = (err)-> [err, null]
    try 
        js = compile livescript-code, {bare: true}
    catch err
        return die "livescript transpilation error: #{err.to-string!}"
    try 
        result = vm.run-in-new-context js, context
    catch err
        return die "javascript runtime error: #{err.to-string!}"
    [null, result]

export get-all-keys-recursively = (object, filter-function)->
    keys object |> concat-map (key)-> 
        return [] if !filter-function key, object[key]
        return [key] ++ (get-all-keys-recursively object[key], filter-function)  if typeof object[key] == \object
        [key]