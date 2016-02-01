require! \../../config.ls
create-browser-history = require \history/lib/createBrowserHistory
{last, map} = require \prelude-ls
{clone-element, create-factory, DOM:{button, div}}:React = require \react
{render} = require \react-dom
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

    mixins: [react-router.History]

    # render :: a -> ReactElement
    render: ->
        div null,

            # pass spy.record method as props to child component
            clone-element @props.children, {} <<< config <<< 
                record: @?record ? (->)

            div {class-name: \building}, \Building... if @state.building

    # get-initial-state :: a -> UIState
    get-initial-state: -> building: false

    # component-did-mount :: a -> Void
    component-will-mount: !->
        if !!config?.gulp?.reload-port
            (require \socket.io-client) "http://localhost:#{config.gulp.reload-port}"
                ..on \build-start, ~> @set-state building: true
                ..on \build-complete, -> window.location.reload!

        if !!config?.spy?.enabled

            {get-load-time-object, record} = (require \spy-web-client) do 
                url: config.spy.url
                common-event-properties : ~>

                    # viewbag is a JSON object rendered by the server into index.html 
                    # it contains the user-id, session-id etc...
                    {} <<< viewbag <<< 
                        route: (last @props.routes)?.name ? \index

            @record = record

            # record page-ready event            
            get-load-time-object (load-time-object) ~>
                record do 
                    event-type: \load
                    event-args: load-time-object

            # record clicks
            @click-listener = ({target, type, pageX, pageY}:e?) ~>

                # find-parent-id :: DOMElement -> String
                find-parent-id = (element) ->
                    return switch
                        | element.parent-element == null => \unknown
                        | typeof element.id == \string and element.id.length > 0 => element.id
                        | _ => find-parent-id element.parent-element

                record do
                    event-type: \click
                    event-args:
                        type: type 
                        element:
                            parent-id: find-parent-id target
                            id: target.id
                            class: target.class-name
                            client-rect: target.get-bounding-client-rect!
                            tag: target.tag-name
                        x: pageX
                        y: pageY
            document.add-event-listener \click, @click-listener

            # record route change events
            @history.listen (, {routes}) ~>
                record do 
                    event-type: \route-ready
                    event-args: 
                        route: (last routes)?.name ? \index

    # component-will-unmount :: a -> Void
    component-will-unmount: !-> document.remove-event-listener \click, @click-listener if !!@click-listener


<- window.add-event-listener \load
<- set-timeout _, 0

render do 
    Router do 
        history: create-browser-history!
        Route do 
            name: \app
            path: \/
            component: App
            IndexRoute component: QueryListRoute
            Route name: \new-query, path: \/branches component: QueryRoute
            Route name: \existing-query, path: "/branches/:branchId/queries/:queryId" component: QueryRoute
            Route name: \diff, path: "/branches/:branchId/queries/:queryId/diff", component: DiffRoute
            Route name: \ops, path: "/ops", component: OpsRoute
            Route name: \tree, path: "/branches/:branchId/queries/:queryId/tree", component: TreeRoute
            Route name: \import, path: "/import" component: ImportRoute
    document.get-element-by-id \mount-node