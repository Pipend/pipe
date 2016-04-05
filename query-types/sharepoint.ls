{Promise, bind-p, from-error-value-callback, new-promise, return-p, to-callback, with-cancel-and-dispose} = require \../async-ls
{concat-map, each, group-by, Obj, keys, map, obj-to-pairs, pairs-to-obj} = require \prelude-ls
connect-to-sharepoint = require \sharepoint-client
{compile-and-execute-sync} = require \transpilation

export parse-connection-string = (connection-string) ->
    [, username, password, host]? = /sharepoint:\/\/(.*?):(.*?)\/(.*)/g.exec connection-string
    {username, password, host}

# connections :: (CancellablePromise cp) => a -> cp b
export connections = ->
    return-p []

# keywords :: (CancellablePromise cp) => [DataSource, String] -> cp { keywords: [String], tables: Hash {String: [String]} }
export keywords = ([data-source]) ->
    return-p []

# get-context :: a -> Context
export get-context = ->
    {} <<< (require \./default-query-context.ls)!

# for executing a single mongodb query POSTed from client
# execute :: (CancellablePromise cp) => OpsManager -> QueryStore -> DataSource -> String -> String -> Parameters -> cp result
export execute = (, , data-source, query, transpilation-language, compiled-parameters) -->

    # connect to sharepoint
    {host, username, password} = data-source
    {get-list-items} <- bind-p connect-to-sharepoint host, username, password

    # odata-query-per-list :: Map ListName, OdataQuery
    [err, odata-query-per-list] = compile-and-execute-sync query, transpilation-language, compiled-parameters

    if err
        new-promise (, rej) -> rej err

    else
        results-per-list <- bind-p Promise.map do
            obj-to-pairs odata-query-per-list 
            ([list-name, odata-query]) ->
                result <- bind-p (get-list-items list-name, odata-query)
                [list-name, result]

        results-per-list 
            |> pairs-to-obj
            |> return-p

# default-document :: DataSourceCue -> String -> Document
export default-document = (data-source-cue, transpilation-language) -> 
    query: """
    $select: *
    $top: 100
    """
    transformation: "id"
    presentation: "json"
    parameters: ""