{bindP, from-error-value-callback, new-promise, returnP, to-callback, with-cancel} = require \../async-ls
config = require \./../config
{concat-map, each, find, filter, group-by, id, Obj, keys, map, obj-to-pairs, Str} = require \prelude-ls
{exec} = require \shelljs
{compile-and-execute-livescript}:utils = require \./../utils

# keywords :: (CancellablePromise cp) => DataSource -> cp [String]
export keywords = (data-source) ->
    returnP <[curl -H -d -X POST GET --user http:// https://]>

# get-context :: a -> Context
export get-context = ->
    {} <<< (require \./default-query-context.ls)! <<< (require \prelude-ls)

# for executing a single mongodb query POSTed from client
# execute :: (CancellablePromise cp) => DB -> DataSource -> String -> CompiledQueryParameters -> cp result
export execute = (query-database, data-source, query, parameters) -->
    {shell-command, parse} = require \./shell-command-parser
    result = parse shell-command, query
    return (new-promise (, rej) -> rej new Error "Parsing Error #{result.0.1}") if !!result.0.1

    result := result.0.0.args |> concat-map id
    url = result |> find (-> !!it.opt) |> (.opt)
    options = result 
        |> filter (-> !!it.name) 
        |> map ({name, value}) -> 
            (if name.length > 1 then "--" else "-") + name + if !!value then " #value" else ""
        |> Str.join " "

    [err, url] = compile-and-execute-livescript url, parameters
    return (new-promise (, rej) -> rej new Error "Url foramtting failed\n#err") if !!err

    execute-curl = new-promise (res, rej) ->
        process = exec "curl -s #url #{options}", silent: true, (code, output) ->
            return rej Error "Error in curl #code #output", null if code != 0
            try
                json = JSON.parse output
            catch error 
                return rej error
            res json

    execute-curl `with-cancel` -> 
        process.kill!
        returnP \killed

# default-document :: () -> Document
export default-document = -> 
    {
        query: ""
        transformation: "id"
        presentation: "json"
        parameters: ""
    }
