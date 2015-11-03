{bindP, from-error-value-callback, new-promise, returnP, to-callback} = require \../async-ls
{query-database-connection-string, mongo-connection-opitons}:config = require \./../config
{MongoClient} = require \mongodb
{camelize, id, map} = require \prelude-ls

# utils
{compile-and-execute-javascript, compile-and-execute-babel, compile-and-execute-livescript, 
extract-data-source, get-latest-query-in-branch, get-query-by-id, ops-manager, transform}:utils = require \./../utils

# keywords :: (CancellablePromise cp) => [DataSource, String] -> cp [String]
export keywords = ([data-source, transpilation-language]) ->
    returnP keywords: map (if transpilation-language == \livescript then id else camelize), <[run-latest-query run-query]>

# get-context :: () -> Context
export get-context = ->
    {object-id-from-date, date-from-object-id} = require \./../public/utils.ls
    {} <<< (require \./default-query-context.ls)! <<< {object-id-from-date, date-from-object-id} <<< (require \prelude-ls)

# for executing a single mongodb query POSTed from client
# execute :: (CancellablePromise cp) => DB -> DataSource -> String -> CompiledQueryParameters -> cp result
export execute = (query-database, data-source, query, transpilation, parameters) -->
    
    # generate-op-id :: () -> String
    generate-op-id = -> "#{Math.floor Math.random! * 1000}"

    # run-query :: (CancellablePromise) => Query, CompiledQueryParameters? -> cp result
    run-query = (document, parameters = {}) ->
        
        # get the data-source from data-source-cue
        {query-id, branch-id, query-title, data-source-cue, query, transformation, transpilation}? = document
        data-source <- bindP (extract-data-source data-source-cue)

        # execute the query
        {result} <- bindP do ->
            ops-manager.execute do 
                query-database
                data-source
                query
                transpilation?.query
                parameters
                false
                generate-op-id!
                document:
                    query-id: query-id
                    branch-id: branch-id
                    query-title: query-title
                    data-source-cue: data-source-cue

        transform result, transformation, parameters    

    [err, transpiled-code] = (match transpilation
        | \javascript => compile-and-execute-javascript "f = #{query}"
        | \babel => compile-and-execute-babel "f = #{query}"
        | _ => compile-and-execute-livescript query) {} <<< get-context! <<< (require \prelude-ls) <<< parameters <<< (require \../async-ls) <<<

            # run-query :: (CancellablePromise) => String, CompiledQueryParameters? -> cp result
            run-query: (query-id, parameters = {}) ->
                document <- bindP (get-query-by-id query-database, query-id)
                run-query document, parameters

            # run-latest-query :: (CancellablePromise) => String, CompiledQueryParameters? -> cp result
            run-latest-query: (branch-id, parameters = {}) ->
                document <- bindP (get-latest-query-in-branch query-database, branch-id)
                run-query document, parameters

    if !!err then (new-promise (, rej) -> rej err) else transpiled-code

# default-document :: DataSourceCue -> String -> Document
export default-document = (data-source-cue, transpilation-language) -> 
    console.log \transpilation-language, transpilation-language
    query: switch transpilation-language 
        | \livescript => 'run-query "", {}'
        | _ => 'runQuery("", {})'
    transformation: \id
    presentation: \json
    parameters: ""

