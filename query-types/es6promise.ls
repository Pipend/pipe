{bindP, from-error-value-callback, new-promise, returnP, to-callback, with-cancel-and-dispose} = require \../async-ls
config = require \./../config
{concat-map, each, find, filter, group-by, id, Obj, keys, map, obj-to-pairs, Str} = require \prelude-ls
{compile-and-execute-sync} = require \transpilation

# keywords :: (CancellablePromise cp) => [DataSource, String] -> cp [String]
export keywords = ([data-source]) ->
    returnP keywords: <[]>

# get-context :: a -> Context
export get-context = ->
    {} <<< (require \./default-query-context.ls)! <<< (require \prelude-ls)

# for executing a single query POSTed from client
# execute :: (CancellablePromise cp) => TaskManager -> QueryStore -> DataSource -> String -> String -> Parameters -> cp result
export execute = (, , data-source, query, transpilation-language, parameters) -->

    execute = do ->
      [err, transpiled-code] = compile-and-execute-sync do
          query
          transpilation-language
          {} <<< get-context! <<< (require \prelude-ls) <<< parameters <<< (require \../async-ls) <<< (require: require) <<<

              # run-query :: (CancellablePromise) => String, Int, Parameters? -> cp result
              run-query: (query-id, version, parameters = {}) ->
                  document <- bind-p (get-document-version query-id, version)
                  run-query document, parameters

              # run-latest-query :: (CancellablePromise) => String, Parameters? -> cp result
              run-latest-query: (branch-id, parameters = {}) ->
                  document <- bind-p (get-latest-document branch-id)
                  run-query document, parameters

      if err then (new-promise (, rej) -> rej err) else transpiled-code

    with-cancel-and-dispose do
        execute
        ->
            returnP 'cannot cancel'
        ->
            # cancel

# default-document :: DataSourceCue -> String -> Document
export default-document = (data-source-cue, transpilation-language) ->
    query: """new Promise((resolve, reject) => {
        resolve({hello: 'world!'})
      }) """
    transformation: "id"
    presentation: "json"
    parameters: ""
