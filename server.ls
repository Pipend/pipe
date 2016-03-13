{bind-p, from-error-value-callback, new-promise, return-p, to-callback, with-cancel-and-dispose} = require \./async-ls
require! \body-parser
{http-port}:config = require \./config
require! \express
{each, fold, map, reject, Str} = require \prelude-ls

# QueryStore
err, persistent-store <- to-callback do 
    (require "./persistent-stores/#{config.persistent-store.name}") config.persistent-store[config.persistent-store.name]

if err 
    console.log "unable to connect to query store: #{err.to-string!}"
    return

else
    console.log "successfully connected to query store"

# CacheStore
err, memory-store <- to-callback do 
    (require "./memory-stores/#{config.memory-store.name}") config.memory-store[config.memory-store.name]

if err 
    console.log "unable to connect to cache store: #{err.to-string!}"
    return

else
    console.log "successfully connected to cache store"

# TaskManager
require! \./TaskManager
task-manager = new TaskManager memory-store

# Spy
pipend-spy = (require \pipend-spy) config?.spy?.storage-details
spy =
    | config?.spy?.enabled => pipend-spy
    | _ => 
        record: (event-object) -> return-p [event-object]
        record-req: (req, event-object) -> return-p [event-object]

{public-actions, authentication-dependant-actions, authorization-dependant-actions} = (require \./actions) do 
    persistent-store
    task-manager

routes = (require \./routes) do 
    config.authentication.strategies
    {public-actions, authentication-dependant-actions, authorization-dependant-actions}
    spy

app = express!
    ..set \views, __dirname + \/
    ..engine \.html, (require \ejs).__express
    ..set 'view engine', \ejs

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