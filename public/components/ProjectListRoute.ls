{filter, map} = require \prelude-ls
{create-class, create-factory, DOM:{div, input}}:React = require \react
Menu = create-factory require \./Menu.ls
Project = create-factory require \./Project.ls

module.exports = create-class do

    display-name: \ProjectListRoute

    # render :: () -> ReactElement
    render: ->
        div class-name: \project-list-route,

            # MENU
            Menu do 
                items-left: 
                    *   label: 'New Project'
                        action: ->
                            console.log arguments
                    ...

            div class-name: \project-list,

                # SEARCH
                input do 
                    class-name: \search
                    placeholder: 'Search...'
                    type: \text
                    value: @state.search
                    on-change: ({current-target:{value}}) ~>
                        @set-state search: value

                # PROJECTS
                div class-name: \projects,
                    @state.projects 
                        |> filter (project) ~>
                            (project.title.to-lower-case!.index-of @state.search.to-lower-case!) != -1
                        |> map ({_id}:project) ~> 

                            # PROJECT
                            Project {} <<< project <<< 
                                key: _id
                                documents-link: "projects/#{_id}/documents"


    # component-will-mount :: () -> ()
    component-will-mount: !->
        (fetch do 
            \apis/projects
            credentials: \same-origin)
            .then (.json!) 
            .then (projects) ~>
                @set-state {projects}

    # get-initial-state :: () -> UIState
    get-initial-state: ->
        projects: []
        search: ""