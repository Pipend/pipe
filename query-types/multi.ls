{bind-p, from-error-value-callback, new-promise, return-p, to-callback} = require \../async-ls
{query-database-connection-string, mongo-connection-opitons}:config = require \./../config
{MongoClient} = require \mongodb
{camelize, id, map} = require \prelude-ls
{extract-data-source}:utils = require \./../utils
{compile-and-execute-sync} = require \transpilation
{compile-transformation} = require \pipe-transformation

# keywords :: (CancellablePromise cp) => [DataSource, String] -> cp [String]
export keywords = ([data-source, transpilation-language]) ->
    return-p keywords: map (if transpilation-language == \livescript then id else camelize), <[run-latest-query run-query]>

# get-context :: () -> Context
export get-context = ->
    {object-id-from-date, date-from-object-id} = require \../public/lib/utils
    {} <<< (require \./default-query-context.ls)! <<< {object-id-from-date, date-from-object-id} <<< (require \prelude-ls)

# for executing a single mongodb query POSTed from client
# execute :: (CancellablePromise cp) => TaskManager -> Store1 -> DataSource -> String -> String -> Parameters -> cp result
# Store1 ::
#   get-document-version :: String -> Int -> cp Document 
#   get-latest-document :: String -> cp Document
export execute = (execute, {get-document-version, get-latest-document}, data-source, query, transpilation-language, compiled-parameters) -->

    # run-query :: (CancellablePromise) => Query, CompiledQuerycompiled-parameters? -> cp result
    run-query = (document, compiled-parameters = {}) ->
        
        {document-id, version, data-source-cue, query, transformation, transpilation}? = document
        
        # get the data-source from data-source-cue
        data-source <- bind-p (extract-data-source data-source-cue)

        # execute the query
        {result} <- bind-p do ->
            execute do 
                document-id: document-id
                version: version
                document-title: query-title
                query-type: data-source.query-type
                data-source
                query
                transpilation?.query
                compiled-parameters
                false
        transformation-function <- bind-p (compile-transformation transformation, transpilation.transformation)
        transformation-function result, compiled-parameters

    [err, transpiled-code] = compile-and-execute-sync do 
        query
        transpilation-language
        {} <<< get-context! <<< (require \prelude-ls) <<< compiled-parameters <<< (require \../async-ls) <<<

            # run-query :: (CancellablePromise) => String, Int, Parameters? -> cp result
            run-query: (query-id, version, compiled-parameters = {}) ->
                document <- bind-p (get-document-version query-id, version)
                run-query document, compiled-parameters

            # run-latest-query :: (CancellablePromise) => String, Parameters? -> cp result
            run-latest-query: (branch-id, compiled-parameters = {}) ->
                document <- bind-p (get-latest-document branch-id)
                run-query document, compiled-parameters

    if err then (new-promise (, rej) -> rej err) else transpiled-code

# default-document :: DataSourceCue -> String -> Document
export default-document = (data-source-cue, transpilation-language) -> 
    query: switch transpilation-language 
        | \livescript => 'run-query "", {}'
        | _ => 'runQuery("", {})'
    transformation: \id
    presentation: \json
    compiled-parameters: ""

