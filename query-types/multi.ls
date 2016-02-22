{bind-p, from-error-value-callback, new-promise, return-p, to-callback} = require \../async-ls
{query-database-connection-string, mongo-connection-opitons}:config = require \./../config
{MongoClient} = require \mongodb
{camelize, id, map} = require \prelude-ls
{extract-data-source, get-latest-query-in-branch, get-query-by-id, ops-manager, transform}:utils = require \./../utils
{compile-and-execute-sync} = require \transpilation
{compile-transformation} = require \pipe-transformation

# keywords :: (CancellablePromise cp) => [DataSource, String] -> cp [String]
export keywords = ([data-source, transpilation-language]) ->
    return-p keywords: map (if transpilation-language == \livescript then id else camelize), <[run-latest-query run-query]>

# get-context :: () -> Context
export get-context = ->
    {object-id-from-date, date-from-object-id} = require \./../public/utils.ls
    {} <<< (require \./default-query-context.ls)! <<< {object-id-from-date, date-from-object-id} <<< (require \prelude-ls)

# for executing a single mongodb query POSTed from client
# execute :: (CancellablePromise cp) => QueryStore -> DataSource -> String -> String -> Parameters -> cp result
export execute = (
    {get-query-by-id, get-latest-query-in-branch}:query-store
    data-source
    query
    transpilation-language
    compiled-parameters
) -->
    
    # generate-op-id :: () -> String
    generate-op-id = -> "#{Math.floor Math.random! * 1000}"

    # run-query :: (CancellablePromise) => Query, CompiledQuerycompiled-parameters? -> cp result
    run-query = (document, compiled-parameters = {}) ->
        
        # get the data-source from data-source-cue
        {query-id, branch-id, query-title, data-source-cue, query, transformation, transpilation}? = document
        data-source <- bind-p (extract-data-source data-source-cue)

        # execute the query
        {result} <- bind-p do ->
            ops-manager.execute do 
                query-store
                data-source
                query
                transpilation?.query
                compiled-parameters
                false
                generate-op-id!
                document:
                    query-id: query-id
                    branch-id: branch-id
                    query-title: query-title
                    data-source-cue: data-source-cue

        transformation-function <- bind-p compile-transformation transformation, transpilation.transformation
        return-p transformation-function result, compiled-parameters

    [err, transpiled-code] = compile-and-execute-sync do 
        query
        transpilation-language
        {} <<< get-context! <<< (require \prelude-ls) <<< compiled-parameters <<< (require \../async-ls) <<<

            # run-query :: (CancellablePromise) => String, Parameters? -> cp result
            run-query: (query-id, compiled-parameters = {}) ->
                document <- bind-p (get-query-by-id query-id)
                run-query document, compiled-parameters

            # run-latest-query :: (CancellablePromise) => String, Parameters? -> cp result
            run-latest-query: (branch-id, compiled-parameters = {}) ->
                document <- bind-p (get-latest-query-in-branch branch-id)
                run-query document, compiled-parameters

    if !!err then (new-promise (, rej) -> rej err) else transpiled-code

# default-document :: DataSourceCue -> String -> Document
export default-document = (data-source-cue, transpilation-language) -> 
    query: switch transpilation-language 
        | \livescript => 'run-query "", {}'
        | _ => 'runQuery("", {})'
    transformation: \id
    presentation: \json
    compiled-parameters: ""

