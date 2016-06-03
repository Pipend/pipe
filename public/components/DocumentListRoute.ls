{filter, map, sort-by} = require \prelude-ls
{create-class, create-factory, DOM:{a, div, img, input, span}}:React = require \react
Document = create-factory require \./Document.ls
Menu = create-factory require \./Menu.ls
require! \moment
require! \react-router

module.exports = create-class do

    display-name: \DocumentListRoute

    # render :: a -> ReactElement
    render: ->
        div class-name: \document-list-route,

            # MENU
            Menu do
                items-left: 
                    *   label: 'New Document'
                        action: ->
                            debugger
                            react-router.browser-history.replace do 
                                pathname: "/projects/#{@props.params.project-id}/documents/new"
                                query: {}
                    ...

                items-right:
                    *   label: 'Share'
                    *   label: 'Data Sources'
            
            div class-name: \document-list,

                # SEARCH
                input do 
                    class-name: \search
                    placeholder: 'Search...'
                    type: \text
                    value: @state.search
                    on-change: ({current-target:{value}}) ~>
                        @set-state search: value

                # DOCUMENTS
                div class-name: \documents,
                    @state.documents 
                    |> filter ({title}?) ~> (title?.to-lower-case!?.index-of @state.search.to-lower-case!) > -1
                    |> sort-by (.creation-time * -1)
                    |> map ({document-id, version, title, creation-time}) ~>

                        # DOCUMENT
                        Document do
                            key: document-id
                            document-link: "/projects/#{@props.params.project-id}/documents/#{document-id}/versions/#{version}"
                            title: title
                            last-saved-by: \Homam
                            last-saved-on: moment creation-time .format 'ddd DD YYYY hh:mm a'


    # component-will-mount :: () -> ()
    component-will-mount: !->
        (fetch do 
            "/apis/projects/#{@props.params.project-id}/documents"
            credentials: \same-origin)
            .then (.json!) 
            .then (documents) ~>
                @set-state {documents}

    # get-initial-state :: a -> UIState
    get-initial-state: -> 
        documents: []
        search: ""