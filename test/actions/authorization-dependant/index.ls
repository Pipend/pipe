{each} = require \prelude-ls

describe \authorization-dependant, ->
    <[projects documents execution datasources]> |> each (filename) ->
        require "./#{filename}"