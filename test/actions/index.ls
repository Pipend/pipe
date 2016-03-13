{each} = require \prelude-ls

describe \actions, ->
    <[public authentication-dependant authorization-dependant]> |> each (directory) ->
        require "./#{directory}"