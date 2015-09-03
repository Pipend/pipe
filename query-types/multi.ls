{bindP, from-error-value-callback, new-promise, returnP, to-callback} = require \../async-ls
{query-database-connection-string, mongo-connection-opitons}:config = require \./../config
{MongoClient} = require \mongodb
{map} = require \prelude-ls
{compile-and-execute-livescript, extract-data-source, get-latest-query-in-branch, get-query-by-id, transform}:utils = require \./../utils

# keywords :: (CancellablePromise cp) => DataSource -> cp [String]
export keywords = (data-source) ->
    returnP <[run-latest-query run-query]>

# get-context :: () -> Context
export get-context = ->
    {object-id-from-date, date-from-object-id} = require \./../public/utils.ls
    {} <<< (require \./default-query-context.ls)! <<< {object-id-from-date, date-from-object-id} <<< (require \prelude-ls)

# for executing a single mongodb query POSTed from client
# execute :: (CancellablePromise cp) => DB -> DataSource -> String -> CompiledQueryParameters -> cp result
export execute = (query-database, data-source, query, transpilation, parameters) -->
    
    # generate-op-id :: () -> String
    generate-op-id = -> "#{Math.floor Math.random! * 1000}"

    [err, transpiled-code] = compile-and-execute-livescript do
        query
        {} <<< get-context! <<< (require \prelude-ls) <<< parameters <<< (require \../async-ls) <<< {

            # run-query :: (CancellablePromise) => String -> CompiledQueryParameters -> cp result
            run-query: (query-id, parameters) -->
                {data-source-cue, query, transformation, transpilation}:result <- bindP (get-query-by-id query-database, query-id)
                data-source <- bindP (extract-data-source data-source-cue)
                {result} <- bindP utils.execute query-database, data-source, query, transpilation, parameters, false, generate-op-id!
                transform result, transformation, parameters

            # run-latest-query :: (CancellablePromise) => String -> CompiledQueryParameters -> cp result
            run-latest-query: (branch-id, parameters) -->
                {data-source-cue, query, transformation, transpilation}:result <- bindP (get-latest-query-in-branch query-database, branch-id)
                data-source <- bindP (extract-data-source data-source-cue)
                {result} <- bindP (utils.execute query-database, data-source, query, transpilation, parameters, false, generate-op-id!)
                transform result, transformation, parameters
                
        }
    return (new-promise (, rej) -> rej err) if !!err
    transpiled-code

# default-document :: () -> Document
export default-document = -> 
    {
        query: """run-query "", {}"""
        transformation: "id"
        presentation: "json"
        parameters: ""
    }
