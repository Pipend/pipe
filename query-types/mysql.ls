{bindP, from-error-value-callback, new-promise, returnP, to-callback, with-cancel-and-dispose} = require \../async-ls
config = require \./../config
{concat-map, each, group-by, Obj, keys, map, obj-to-pairs} = require \prelude-ls
mysql = require \mysql

# execute-sql :: (CancellablePromise cp) => DataSource -> String -> cp result
execute-sql = (data-source, query) -->
    connection = null

    execute-sql-promise = new-promise (res, rej) ->
        connection := mysql.create-connection data-source
            ..connect!
            ..query query, (err, rows) -> if !!err then rej err else res rows

    with-cancel-and-dispose do 
        execute-sql-promise
        -> returnP \killed
        -> if !!connection then connection.end!

# connections :: (CancellablePromise cp) => a -> cp b
export connections = ->
    returnP do 
        connections: (config?.connections?.mysql or {}) 
            |> obj-to-pairs
            |> map ([name, value]) ->
                label: (value?.label or name)
                value: name
                default-database: value?.default-database or ''

# keywords :: (CancellablePromise cp) => [DataSource, String] -> cp [String]
export keywords = ([data-source, transpilation-language]) ->
    results <- bindP (execute-sql data-source, "select table_schema, table_name, column_name from information_schema.columns")    
    tables = results |> (group-by (-> "#{it.table_schema}.#{it.table_name}")) >> (Obj.map map (.column_name))
    returnP {
        keywords: <[SELECT GROUP BY TOP ORDER WITH DISTINCT INNER OUTER JOIN]>
        tables: tables
    }

# get-context :: a -> Context
export get-context = ->
    {} <<< (require \./default-query-context.ls)!

# for executing a single mongodb query POSTed from client
# execute :: (CancellablePromise cp) => OpsManager -> QueryStore -> DataSource -> String -> CompiledQueryParameters -> cp result
export execute = (, , data-source, query, transpilation, parameters) -->
    (Obj.keys parameters) |> each (key) ->
        query := query.replace "$#{key}$", parameters[key]
    execute-sql data-source, query

# default-document :: DataSourceCue -> String -> Document
export default-document = (data-source-cue, transpilation-language) -> 
    query: """
    select * 
    from 
    limit 10
    """
    transformation: "id"
    presentation: "json"
    parameters: ""
