{bindP, from-error-value-callback, new-promise, returnP, to-callback, with-cancel-and-dispose} = require \../async-ls
config = require \./../config
{concat-map, each, group-by, Obj, keys, map, obj-to-pairs} = require \prelude-ls
pg = require \pg

# execute-sql :: (CancellablePromise cp) => DataSource -> String -> cp result
execute-sql = ({user, password, host, port, database}, query) -->
    client = null

    execute-sql-promise = new-promise (res, rej) ->
        client := new pg.Client "postgres://#{user}:#{password}@#{host}:#{port}/#{database}"
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
    [, user, password, host, , port, database]:result? = connection-string.match /postgres\:\/\/([a-zA-Z0-9\_]*)\:([a-zA-Z0-9\_]*)\@([a-zA-Z0-9\_\.]*)(\:(\d*))?\/(\w*)/
    {user, password, host, port, database}

# connections :: (CancellablePromise cp) => a -> cp b
export connections = ->
    returnP do 
        connections: (config?.connections?.postgresql or {}) 
            |> obj-to-pairs
            |> map ([name, value]) ->
                label: (value?.label or name)
                value: name
                default-database: value?.default-database or ''

# keywords :: (CancellablePromise cp) => DataSource -> cp [String]
export keywords = (data-source) ->
    results <- bindP (execute-sql data-source, "select table_schema, table_name, column_name from information_schema.columns where table_schema = 'public'")    
    returnP <[SELECT GROUP BY TOP ORDER WITH DISTINCT INNER OUTER JOIN RANK PARTITION OVER ST_MAKEPOINT ST_MAKEPOLYGON ROW_NUMBER]> ++ (results
        |> group-by (.table_schema)
        |> Obj.map group-by (.table_name) 
        |> Obj.map Obj.map map (.column_name)
        |> Obj.map obj-to-pairs >> concat-map ([table, columns]) -> [table] ++ do -> columns |> map ("#{table}." +)
        |> obj-to-pairs
        |> concat-map (.1))

# get-context :: a -> Context
export get-context = ->
    {} <<< (require \./default-query-context.ls)!

# for executing a single mongodb query POSTed from client
# execute :: (CancellablePromise cp) => DB -> DataSource -> String -> CompiledQueryParameters -> cp result
export execute = (query-database, data-source, query, transpilation, parameters) -->
    (Obj.keys parameters) |> each (key) ->
        query := query.replace "$#{key}$", parameters[key]
    execute-sql data-source, query

# default-document :: () -> Document
export default-document = -> 
    {
        query: """
        select * 
        from 
        limit 10
        """
        transformation: "id"
        presentation: "json"
        parameters: ""
    }
