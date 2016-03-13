{each} = require \prelude-ls

describe \authentication-dependant, ->
    <[projects]> |> each (filename) ->
        require "./#{filename}"