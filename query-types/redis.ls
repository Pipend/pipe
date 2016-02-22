{return-p} = require \../async-ls

# keywords :: (CancellablePromise cp) => [DataSource, String] -> cp [String]
export keywords = ([data-source]) -> return-p <[]>

# parse-connection-string :: String -> DataSource
export parse-connection-string = (connection-string) ->
    [, host, port]? = /redis:\/\/(.*?):(.*?)\/(\d+)?/g.exec connection-string
    {host, port}

# get-context :: a -> Context
export get-context = -> {}

# for executing a single mongodb query POSTed from client
# execute :: (CancellablePromise cp) => QueryStore -> DataSource -> String -> CompiledQueryParameters -> cp result
export execute = (, data-source, query, transpilation, parameters) --> return-p null

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
        result =>
            fromWebSocket("")
                .filter(({name}) => name === "")
                .map(({data}) => JSON.parse(data))
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
    presentation: \json
    parameters: ""
