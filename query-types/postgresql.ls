{bindP, from-error-value-callback, new-promise, returnP, to-callback, with-cancel-and-dispose} = require \../async-ls
config = require \./../config
{concat-map, each, group-by, Obj, keys, map, obj-to-pairs} = require \prelude-ls

# integer-type-parser :: a -> Int
integer-type-parser = (value) -> if (typeof value == \undefined) or value == null then null else parse-int value    
pg = require \pg
    ..types.set-type-parser 20, integer-type-parser
    ..types.set-type-parser 116642, integer-type-parser

# execute-sql :: (CancellablePromise cp) => DataSource -> String -> cp result
execute-sql = ({user, password, host, port, database, connection-string, ssl = false}:connection, query) -->
    client = null

    execute-sql-promise = new-promise (res, rej) ->
        client := new pg.Client do 
            if !!connection-string then connection-string else "postgres://" + (if !!user then "#{user}:#{password}@" else "") + "#{host}:#{port}/#{database}" + (if ssl then "?ssl=true" else "")
        client.connect (err) ->
            return rej err if !!err 
            err, {rows}? <- client.query query 
            if !!err then rej err else res rows

    with-cancel-and-dispose do 
        execute-sql-promise
        -> returnP \killed
        -> if !!client then client.end!

# parse-connection-string :: String -> DataSource
export parse-connection-string = (connection-string) ->
    [, user, password, host, , port, database, queryString]:result? = connection-string.match /postgres\:\/\/([a-zA-Z0-9\_]*)\:([a-zA-Z0-9\_]*)\@([a-zA-Z0-9\_\.\-]*)(\:(\d*))?\/(\w*)(\?.*)?/
    ssl = !!queryString && queryString.indexOf('ssl=true') > -1
    {user, password, host, port, database, ssl}

# connections :: (CancellablePromise cp) => a -> cp b
export connections = (project, {connection-name, database}) --> 
    returnP do 
        connections: (project.connections?.postgresql or {}) 
            |> obj-to-pairs
            |> map ([name, value]) ->
                label: (value?.label or name)
                value: name
                default-database: value?.default-database or ''

# keywords :: (CancellablePromise cp) => [DataSource, String] -> cp [String]
export keywords = ([data-source, transpilation-language]) ->
    results <- bindP (execute-sql data-source, "select table_schema, table_name, column_name from information_schema.columns")
    tables = results |> (group-by (-> "#{it.table_schema}.#{it.table_name}")) >> (Obj.map map (.column_name))
    returnP do
        keywords: <[SELECT GROUP BY ORDER WITH DISTINCT INNER OUTER JOIN RANK PARTITION OVER ST_MAKEPOINT ST_MAKEPOLYGON ROW_NUMBER]>
        tables: tables

# get-context :: a -> Context
export get-context = ->
    {} <<< (require \./default-query-context.ls)!

export compile-query = (query, transpilation, parameters) -->

    (Obj.keys parameters) |> each (key) ->
        query := query.replace "$#{key}$", parameters[key]

    query

# for executing a single mongodb query POSTed from client
# execute :: (CancellablePromise cp) => TaskManager -> QueryStore -> DataSource -> String -> CompiledQueryParameters -> cp result
export execute = (, , data-source, query, transpilation, parameters) -->

    execute-sql data-source, (compile-query query, transpilation, parameters)

# default-document :: DataSourceCue -> String -> Document
export default-document = -> 
    query: """
    select * 
    from 
    limit 10
    """
    transformation: "id"
    presentation: "json"
    parameters: ""
