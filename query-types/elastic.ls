{bindP, from-error-value-callback, new-promise, returnP, to-callback, with-cancel-and-dispose} = require \../async-ls
config = require \./../config
{concat-map, each, group-by, Obj, keys, map, obj-to-pairs} = require \prelude-ls
{Client} = require \elasticsearch
{compile-and-execute-livescript, compile-and-execute-babel, compile-and-execute-javascript} = require \../utils

# parse-connection-string :: String -> DataSource
export parse-connection-string = (connection-string) ->
    [, host, index, type]? = /elastic:\/\/(.*)?\/(.*)?\/(.*)?/g.exec connection-string
    {host, index, type}

# connections :: (CancellablePromise cp) => a -> cp b
export connections = ->

# keywords :: (CancellablePromise cp) => [DataSource, String] -> cp { keywords: [String], tables: Hash {String: [String]} }
export keywords = ([data-source]) ->

# get-context :: a -> Context
export get-context = ->
    {} <<< (require \./default-query-context.ls)!

# for executing a single mongodb query POSTed from client
# execute :: (CancellablePromise cp) => DB -> DataSource -> String -> CompiledQueryParameters -> cp result
export execute = (query-database, {host, index, type}, query, transpilation, parameters) -->
    client = null

    with-cancel-and-dispose do 
        new-promise (res, rej) ->
            client := new Client {host}
            [err, q] = compile-and-execute-livescript query, {} <<< get-context! <<< (require \prelude-ls) <<< parameters
            if !!err 
                rej err 
            else
                (client.search do 
                    index: index
                    type: type 
                    headers:
                        'Accept-Encoding': 'gzip, deflate'
                    body: q)
                        .then res
                        .catch rej
        -> return-p \killed
        -> 

# default-document :: DataSourceCue -> String -> Document
export default-document = (data-source-cue, transpilation-language) -> 
    {
        query: """
        query: 
            match: '': ''
        """
        transformation: "id"
        presentation: "json"
        parameters: ""
    }
