{each} = require \prelude-ls

describe \authorization-dependant, ->
    <[users]> |> each (filename) ->
        require "./#{filename}"