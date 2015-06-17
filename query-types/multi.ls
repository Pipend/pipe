{bindP, from-error-value-callback, new-promise, returnP, to-callback, with-cancel} = require \../async-ls
{query-database-connection-string, mongo-connection-opitons}:config = require \./../config
{MongoClient} = require \mongodb
{map} = require \prelude-ls
{compile-and-execute-livescript, get-latest-query-in-branch, get-query-by-id, transform}:utils = require \./../utils

# keywords :: (CancellablePromise cp) => DataSource -> cp [String]
export keywords = (data-source) ->
    returnP <[run-latest-query run-query]>

# get-context :: () -> Context
export get-context = ->
    {object-id-from-date, date-from-object-id} = require \./../public/utils.ls
    {} <<< (require \./default-query-context.ls)! <<< {object-id-from-date, date-from-object-id} <<< (require \prelude-ls)

# for executing a single mongodb query POSTed from client
# execute :: (CancellablePromise cp) => DB -> DataSource -> String -> CompiledQueryParameters -> cp result
export execute = (query-database, data-source, query, parameters) -->
    
    # generate-op-id :: () -> String
    generate-op-id = -> "#{Math.floor Math.random! * 1000}"

    [err, transpiled-code] = compile-and-execute-livescript do
        query
        {} <<< get-context! <<< (require \prelude-ls) <<< parameters <<< (require \../async-ls) <<< {

            # run-query :: (CancellablePromise) => String -> CompiledQueryParameters -> cp result
            run-query: (query-id, parameters) -->
                {data-source, query, transformation}:result <- bindP (get-query-by-id query-database, query-id)
                query-result <- bindP utils.execute query-database, data-source, query, parameters, false, generate-op-id!
                transform query-result, transformation, parameters

            # run-latest-query :: (CancellablePromise) => String -> CompiledQueryParameters -> cp result
            run-latest-query: (branch-id, parameters) -->
                {data-source, query, transformation}:result <- bindP (get-latest-query-in-branch query-database, branch-id)
                query-result <- bindP (utils.execute query-database, data-source, query, parameters, false, generate-op-id!)
                transform query-result, transformation, parameters
                
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