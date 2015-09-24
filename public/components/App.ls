require! \./AceEditor.ls
require! \../../config.ls
{map} = require \prelude-ls
{create-factory, DOM:{button, div}}:React = require \react
{HistoryLocation, Navigation, RouteHandler, State} = Router = require \react-router
DefaultRoute = create-factory Router.DefaultRoute
Route = create-factory Router.Route

# routes
require! \./DiffRoute.ls
require! \./OpsRoute.ls
require! \./QueryRoute.ls
require! \./QueryListRoute.ls
require! \./TreeRoute.ls
require! \./ImportRoute.ls

App = React.create-class do

    display-name: \App

    mixins: [Navigation, State]

    # render :: a -> ReactElement
    render: ->
        div null,
            React.create-element do 
                RouteHandler
                params: @get-params!
                query: @get-query!
                auto-reload: !!config?.gulp?.reload-port
            div {class-name: \building}, \Building... if @state.building

    # get-initial-state :: a -> UIState
    get-initial-state: -> building: false

    # component-did-mount :: a -> Void
    component-did-mount: !->
        if !!config?.gulp?.reload-port
            (require \socket.io-client) "http://localhost:#{config.gulp.reload-port}"
                ..on \build-start, ~> @set-state building: true
                ..on \build-complete, -> window.location.reload!

handler <- Router.run do  
    React.create-element Route, {name: \app, path: \/, handler: App},
        Route name: \new-query, path: "/branches" handler: QueryRoute
        Route name: \existing-query, path: "/branches/:branchId/queries/:queryId" handler: QueryRoute
        Route name: \diff, path: "/branches/:branchId/queries/:queryId/diff", handler: DiffRoute
        Route name: \ops, path: "/ops", handler: OpsRoute
        Route name: \tree, path: "/branches/:branchId/queries/:queryId/tree", handler: TreeRoute
        Route name: \import, path: "/import" handler: ImportRoute
        DefaultRoute handler: QueryListRoute
    HistoryLocation

React.render do 
    React.create-element handler, null
    document.body

