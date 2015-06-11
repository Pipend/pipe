AceEditor = require \./AceEditor.ls
{gulp-io-port}? = require \../../config.ls
{map} = require \prelude-ls
{DOM:{button, div}}:React = require \react
{DefaultRoute, HistoryLocation, Navigation, Route, RouteHandler, State} = Router = require \react-router

# routes
DiffRoute = require \./DiffRoute.ls
QueryRoute = require \./QueryRoute.ls
QueryListRoute = require \./QueryListRoute.ls


App = React.create-class {

    display-name: \App

    mixins: [Navigation, State]

    render: ->
        div null,
            React.create-element RouteHandler, {
                params: @.get-params!
                query: @.get-query!
            }
            div {class-name: \building}, \Building... if @.state.building

    get-initial-state: ->
        {building: false}

    component-did-mount: ->
        if !!gulp-io-port
            (require \socket.io-client) "http://localhost:#{gulp-io-port}"
                ..on \build-start, ~> @.set-state {building: true}
                ..on \build-complete, -> window.location.reload!

}

handler <- Router.run do  
    React.create-element Route, {name: \app, path: \/, handler: App},
        React.create-element Route, {name: \new-query, path: "/branches" handler: QueryRoute}
        React.create-element Route, {name: \existing-query, path: "/branches/:branchId/queries/:queryId" handler: QueryRoute}
        React.create-element Route, {name: \diff, path: "/branches/:branchId/queries/:queryId/diff", handler: DiffRoute}
        React.create-element DefaultRoute, {handler: QueryListRoute}
    HistoryLocation

React.render (React.create-element handler, null), document.body

