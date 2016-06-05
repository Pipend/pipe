{filter, map, sort-by, camelize} = require \prelude-ls
{create-class, create-factory, DOM:{a, div, img, input, span}}:React = require \react
Document = create-factory require \./Document.ls
Menu = create-factory require \./Menu.ls
NewProjectDialog = create-factory require \./NewProjectDialog.ls
require! \moment
require! \react-router
pipe-web-client = (require \pipe-web-client) window.location.origin

module.exports = create-class do

    display-name: \NewProjectRoute

    # render :: a -> ReactElement
    render: ->

        div class-name: \new-project-route,

            # MENU
            Menu do
                items-left: []

                items-right: []
            
            div null,

                NewProjectDialog do
                    project: @state.project
                    on-change: (project) ~>
                        @set-state {project}
                    save: (project) ~>

                        (pipe-web-client project._id)[camelize (if !!project._id then 'update-project' else 'add-project')] project
                            .then (x) ->
                                react-router.browser-history.push pathname: "/projects/#{x._id}"

                            .catch (ex) ->
                                console.error ex

    # component-will-mount :: () -> ()
    component-will-mount: !->

        if !!@props.params.project-id
            (pipe-web-client @props.params.project-id).get-project!
                .then (project) ~> @set-state {project}
                .catch (ex) -> console.error ex
        

    # get-initial-state :: a -> UIState
    get-initial-state: ->  
        project:
            title: ''
            permission: 'publicReadable'
            connections: {}