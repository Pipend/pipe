moment = require \moment

module.exports = ->
    parse-date = (s) -> new Date s
    today = -> ((moment!start-of \day .format "YYYY-MM-DDT00:00:00.000") + \Z) |> parse-date
    to-timestamp = (s) -> (moment (new Date s)).unix! * 1000
    {
        get-today: today
        moment
        parse-date
        today: today!
        to-timestamp
    }