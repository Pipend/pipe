{filter, map, sort-by} = require \prelude-ls
{create-class, DOM:{div, img, input}} = require \react
pipe-web-client = (require \pipe-web-client) "http://#{window.location.host}"

module.exports = create-class do 

    display-name: \DocumentSearch

    # get-default-props :: () -> Props
    get-default-props: ->
        project-id: ""
        style: {}

    # render :: () -> ReactElement
    render: ->
        div do 
            class-name: \document-search
            style: @props.style

            # SEARCH
            input do 
                class-name: \search
                placeholder: 'Search...'
                type: \text
                value: @state.search
                on-change: ({current-target:{value}}) ~>
                    @set-state search: value

            div class-name: \documents,
                @state.documents 
                |> filter ({title}?) ~> 
                    (title?.to-lower-case!?.index-of @state.search.to-lower-case!.trim!) > -1
                |> sort-by (.creation-time * -1)
                |> map ({document-id, version, title, creation-time}) ~>

                    # SEARCH ITEM
                    div do 
                        key: document-id
                        class-name: \document-search-item
                        img src: \/public/images/snapshot-placeholder.jpg
                        div class-name: \title, title

    # get-initial-state :: () -> UIState
    get-initial-state: ->
        documents: []
        search: ""

    # component-will-mount :: () -> ()
    component-will-mount: !->
        pipe-web-client @props.project-id .get-documents! 
            .then (documents) ~> @set-state {documents}