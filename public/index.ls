{clone-element, create-factory, DOM:{div}}:React = require \react
{render} = require \react-dom
require! \react-router
Router = create-factory react-router.Router
Route = create-factory react-router.Route
IndexRoute = create-factory react-router.IndexRoute

# # routes
require! \./components/App.ls
require! \./components/ProjectListRoute.ls
require! \./components/DocumentListRoute.ls
require! \./components/DocumentRoute.ls
require! \./components/NewProjectRoute.ls

console.log \react.version, React.version

render do 

    Router do 
        history: react-router.browser-history

        Route do 
            name: \app
            path: \/
            component: App

            IndexRoute component: ProjectListRoute

                            
            Route do
                path: \/projects/new
                component: NewProjectRoute


            Route do 
                path: \/projects/:projectId/edit
                component: NewProjectRoute


            Route do 
                path: \/projects/:projectId
                component: DocumentListRoute

            Route do 
                path: \/projects/:projectId/documents
                component: DocumentListRoute

            Route do 
                path: \/projects/:projectId/documents/new 
                component: DocumentRoute

            Route do 
                path: \/projects/:projectId/documents/:documentId/versions/:version 
                component: DocumentRoute

    document.get-element-by-id \mount-node