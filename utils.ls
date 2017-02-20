{get-all-keys-recursively} = require \./public/lib/utils.ls
{bind-p, new-promise, return-p, reject-p} = require \./async-ls
{all, id, filter, find, map, obj-to-pairs, pairs-to-obj, reject} = require \prelude-ls

# Utility
# reject-keys :: ([String, a] -> Bool) -> Map k, v -> Map k, v
reject-keys = (f, o) -->
    o 
    |> obj-to-pairs
    |> reject f
    |> pairs-to-obj



export get-all-keys-recursively

export extract-data-source = (data-source-cue) ->
            
  # throw error if query-type does not exist
  query-type = require "./query-types/#{data-source-cue?.query-type}"
  if typeof query-type == \undefined
      return new-promie (, rej) -> rej new Error "query type: #{data-source-cue?.query-type} not found"
  
  # clean-data-source :: UncleanDataSource -> DataSource
  clean-data-source = reject-keys (.0 in <[connectionKind complete]>)

  return-p clean-data-source do 
      match data-source-cue?.connection-kind
          | \connection-string => 
              parsed-connection-string = (query-type?.parse-connection-string data-source-cue.connection-string) or {}
              {} <<< data-source-cue <<< parsed-connection-string
          | \pre-configured =>
              connection-prime = project.connections?[data-source-cue?.query-type]?[data-source-cue?.connection-name]
              {} <<< data-source-cue <<< (connection-prime or {})
          | _ => {} <<< data-source-cue