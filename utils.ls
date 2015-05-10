{compile} = require \LiveScript
{map} = require \prelude-ls
vm = require \vm

# all functions in this file are for use on server-side only (either by server.ls or query-types)

exports.compile-and-execute-livescript = (livescript-code, context)->
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