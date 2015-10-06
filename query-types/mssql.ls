{bindP, from-error-value-callback, new-promise, returnP, to-callback, with-cancel-and-dispose} = require \../async-ls
config = require \./../config
{concat-map, each, group-by, Obj, keys, map, obj-to-pairs} = require \prelude-ls
sql = require \mssql

execute-sql = (data-source, query) -->
    connection = null

    execute-sql-promise = new-promise (res, rej) ->
        connection := new sql.Connection data-source, (err) ->
            return rej err  if !!err 
            err, records <- (new sql.Request connection).query query
            if !!err then rej err else res records

    with-cancel-and-dispose do 
        execute-sql-promise
        -> returnP \killed
        -> if !!connection then connection.close!

# connections :: (CancellablePromise cp) => a -> cp b
export connections = ->
    returnP do 
        connections: (config?.connections?.mssql or {}) 
            |> obj-to-pairs
            |> map ([name, value]) ->
                label: (value?.label or name)
                value: name
                default-database: value?.default-database or ''

# keywords :: (CancellablePromise cp) => DataSource -> cp { keywords: [String], tables: Hash {String: [String]} }
export keywords = (data-source) ->
    results <- bindP (execute-sql data-source, "SELECT TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS")
    tables = results |> (group-by (-> "#{it.TABLE_SCHEMA}.#{it.TABLE_NAME}")) >> (Obj.map map (.COLUMN_NAME))
    returnP {
        keywords: <[SELECT GROUP BY TOP ORDER WITH DISTINCT INNER OUTER JOIN (NOLOCK)]>
        tables: tables
    }

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
        select top 100 * from 
        """
        transformation: "id"
        presentation: "json"
        parameters: ""
    }
