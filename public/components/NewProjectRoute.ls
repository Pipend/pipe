{filter, map, sort-by} = require \prelude-ls
{create-class, create-factory, DOM:{a, div, img, input, span}}:React = require \react
Document = create-factory require \./Document.ls
Menu = create-factory require \./Menu.ls
NewProjectDialog = create-factory require \./NewProjectDialog.ls
require! \moment
require! \react-router

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
                        console.log \project-changed, project
                        @set-state {project}

    # component-will-mount :: () -> ()
    component-will-mount: !->
        

    # get-initial-state :: a -> UIState
    get-initial-state: ->  
        project:
            title: ''
            permission: 'publicReadable'
            connections: {}