require! \./AceEditor.ls
require! \../../config.ls
create-browser-history = require \history/lib/createBrowserHistory
{map} = require \prelude-ls
{clone-element, create-factory, DOM:{button, div}}:React = require \react
require! \react-router
Router = create-factory react-router.Router
Route = create-factory react-router.Route
IndexRoute = create-factory react-router.IndexRoute

# routes
require! \./DiffRoute.ls
require! \./OpsRoute.ls
require! \./QueryRoute.ls
require! \./QueryListRoute.ls
require! \./TreeRoute.ls
require! \./ImportRoute.ls

App = React.create-class do

    display-name: \App

    # render :: a -> ReactElement
    render: ->
        div null,
            clone-element @props.children, config
            div {class-name: \building}, \Building... if @state.building

    # get-initial-state :: a -> UIState
    get-initial-state: -> building: false

    # component-did-mount :: a -> Void
    component-did-mount: !->
        if !!config?.gulp?.reload-port
            (require \socket.io-client) "http://localhost:#{config.gulp.reload-port}"
                ..on \build-start, ~> @set-state building: true
                ..on \build-complete, -> window.location.reload!

React.render do 
    Router do 
        history: create-browser-history!
        Route do 
            name: \app
            path: \/
            component: App
            IndexRoute component: QueryListRoute
            Route name: \new-query, path: "/branches" component: QueryRoute
            Route name: \existing-query, path: "/branches/:branchId/queries/:queryId" component: QueryRoute
            Route name: \diff, path: "/branches/:branchId/queries/:queryId/diff", component: DiffRoute
            Route name: \ops, path: "/ops", component: OpsRoute
            Route name: \tree, path: "/branches/:branchId/queries/:queryId/tree", component: TreeRoute
            Route name: \import, path: "/import" component: ImportRoute
    document.body

