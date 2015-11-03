{bindP, from-error-value-callback, new-promise, returnP, to-callback} = require \../async-ls
{query-database-connection-string, mongo-connection-opitons}:config = require \./../config
{map} = require \prelude-ls
{compile-and-execute-livescript, extract-data-source, get-latest-query-in-branch, get-query-by-id, transform}:utils = require \./../utils

# keywords :: (CancellablePromise cp) => [DataSource, String] -> cp [String]
export keywords = ([data-source]) -> returnP <[]>

# parse-connection-string :: String -> DataSource
export parse-connection-string = (connection-string) ->
    [, host, port]? = /redis:\/\/(.*?):(.*?)\/(\d+)?/g.exec connection-string
    {host, port}

# get-context :: a -> Context
export get-context = ->
    {object-id-from-date, date-from-object-id} = require \./../public/utils.ls
    {} <<< (require \./default-query-context.ls)! <<< {object-id-from-date, date-from-object-id} <<< (require \prelude-ls)

# for executing a single mongodb query POSTed from client
# execute :: (CancellablePromise cp) => DB -> DataSource -> String -> CompiledQueryParameters -> cp result
export execute = (query-database, data-source, query, transpilation, parameters) -->
    returnP null

# default-document :: DataSourceCue -> String -> Document
export default-document = (data-source-cue, transpilation-language) -> 
    query: ""
    transformation: switch transpilation-language
        | \livescript => """
        <- id
        from-web-socket \\
            .filter (.name == \\)
            .map ({data}) -> JSON.parse data
        """
        | \babel => """
        (result) => {
            fromWebSocket("")
                .filter ({name}) => name == ""
                .map ({data}) => JSON.parse data
        }
        """
        | \javascript => """
        function(result) {
            fromWebSocket("")
                .filter(function(event){
                    return event.name == "";
                })
                .map(function(event){
                    return event.data;    
                })
        }
        """
    presentation: "json"
    parameters: ""
