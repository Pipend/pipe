# all functions in this file are for use on server-side only (either by server.ls or query-types)
{return-p} = require \./async-ls

require! \./config

# prelude
{dasherize, obj-to-pairs, pairs-to-obj, reject} = require \prelude-ls

{get-all-keys-recursively} = require \./public/utils.ls

export get-all-keys-recursively

# synchronous function, uses promises for encapsulating error
# extract-data-source :: DateSourceCue -> p DataSource
export extract-data-source = (data-source-cue) ->

    # throw error if query-type does not exist
    query-type = require "./query-types/#{data-source-cue?.query-type}"
    if typeof query-type == \undefined
        return new-promie (, rej) -> rej new Error "query type: #{data-source-cue?.query-type} not found"

    # clean-data-source :: UncleanDataSource -> DataSource
    clean-data-source = (unclean-data-source) ->
        unclean-data-source
            |> obj-to-pairs
            |> reject ([key]) -> (dasherize key) in <[connection-kind complete]>
            |> pairs-to-obj

    return-p clean-data-source do 
        match data-source-cue?.connection-kind
            | \connection-string => 
                parsed-connection-string = (query-type?.parse-connection-string data-source-cue.connection-string) or {}
                {} <<< data-source-cue <<< parsed-connection-string
            | \pre-configured =>
                connection-prime = config?.connections?[data-source-cue?.query-type]?[data-source-cue?.connection-name]
                {} <<< data-source-cue <<< (connection-prime or {})
            | _ => {} <<< data-source-cue