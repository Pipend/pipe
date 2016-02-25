{bind-p, from-error-value-callback, new-promise, return-p, to-callback} = require \./async-ls
require! \base62
require! \body-parser
{http-port}:config = require \./config
require! \express
{each, fold, map, reject, Str} = require \prelude-ls

# QueryStore
err, query-store <- to-callback do 
    (require "./query-stores/#{config.query-store.name}") config.query-store[config.query-store.name]

if err 
    console.log "unable to connect to query store: #{err.to-string!}"
    return

else
    console.log "successfully connected to query store"

# CacheStore
err, cache-store <- to-callback do 
    (require "./cache-stores/#{config.cache-store.name}") config.cache-store[config.cache-store.name]

if err 
    console.log "unable to connect to cache store: #{err.to-string!}"
    return

else
    console.log "successfully connected to cache store"

# OpsManager
require! \./OpsManager
ops-manager = new OpsManager cache-store

# Spy
pipend-spy = (require \pipend-spy) config?.spy?.storage-details
spy =
    | config?.spy?.enabled => pipend-spy
    | _ => 
        record: (event-object) -> return-p [event-object]
        record-req: (req, event-object) -> return-p [event-object]

routes = (require \./routes) config.authentication.strategies, query-store, ops-manager, spy

app = express!
    ..set \views, __dirname + \/
    ..engine \.html, (require \ejs).__express
    ..set 'view engine', \ejs
    ..use (require \cors)!
    ..use (require \serve-favicon) __dirname + '/public/images/favicon.png'
    ..use (require \cookie-parser)!

# with-optional-params :: [String] -> [String] -> [String]
with-optional-params = (routes, params) -->
    routes |> fold do 
        (acc, value) ->
            new-routes = [0 to params.length]
                |> map (i) ->
                    [0 til i] 
                        |> map -> ":#{params[it]}"
                        |> Str.join \/
                |> map -> "#{value}/#{it}"
            acc ++ new-routes
        []

# add-to-express-app :: String -> [a] -> ()
add-to-express-app = (method, args) !->
    app[method].apply do 
        app
        args |> reject -> typeof it == \undefined

routes |> each ({
    methods, 
    patterns, 
    middlewares or [], 
    optional-params or [], 
    request-handler
}?) !->
    methods |> each (method) !->
        if patterns
            (patterns `with-optional-params` optional-params) |> each (pattern) -> 
                add-to-express-app do 
                    method
                    [pattern] ++ middlewares ++ [request-handler]

        else
            add-to-express-app do
                method
                middlewares ++ [request-handler]

server = app.listen http-port
console.log "listening for connections on port: #{http-port}"

# emit all the running ops to the client
io = (require \socket.io) server
    ..on \connect, (connection) ->
        connection.emit \ops, ops-manager.running-ops!

ops-manager.on \change, -> io.emit \ops, ops-manager.running-ops!

set-interval do 
    -> io.emit \ops, ops-manager.running-ops!
    1000