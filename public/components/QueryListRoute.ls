require! \./AceEditor.ls
$ = require \jquery-browserify
{any, concat-map, filter, map, partition, unique, sort, take} = require \prelude-ls
{create-factory, DOM:{a, div, img, input, span}}:React = require \react
require! \react-router
{compile-and-execute-livescript} = require \../utils.ls
Link = create-factory react-router.Link

module.exports = React.create-class do

    display-name: \QueryListRoute

    # render :: a -> ReactElement
    render: ->
        {branches, tags, selected-tags, tag-search, query-title-search} = @state
        
        div class-name: \query-list-route,

            # LEFT SIDE MENU
            div do 
                id: \menu
                class-name: \menu

                # NEW QUERY BUTTON
                Link do 
                    id: \new-query
                    class-name: \new-query
                    to: \/branches
                    'New query'

                div class-name: \title, \Tags
                
                # TAG SEARCH CONTAINER (for icon font)
                div class-name: \search-container,

                    # TAG SEARCH INPUT
                    input do
                        id: \tag-search
                        placeholder: \Search
                        type: \text
                        value: @state.tag-search
                        on-change:({current-target: {value}}) ~> @set-state {tag-search: value}

                # LIST OF TAGS
                div do 
                    class-name: \tags
                    tags 
                        |> filter (tag) -> (tag-search.length == 0) or ((tag.to-lower-case!.index-of tag-search.to-lower-case!) != -1)
                        |> map (tag) ~>
                            selected = tag in selected-tags
                            div do
                                id: \menu-tag
                                class-name: "tag #{if selected then 'selected' else ''}"
                                key: tag
                                on-click: ~> 
                                    @set-state do 
                                        selected-tags: 
                                            | selected => selected-tags |> partition (== tag) |> (.1)
                                            | _ => [tag] ++ selected-tags
                                tag
                
                div do 
                    id: \buttons
                    class-name: \buttons
                    
                    # IMPORT BUTTON
                    Link do 
                        id: \import
                        class-name: \import
                        to: \/import
                        'Import'

                    # TASK MANAGER
                    Link do 
                        id: \task-manager
                        class-name: \task-manager
                        to: \/ops
                        'Task Manager'

                # COPYRIGHT
                div class-name: \copy-right,
                    "© #{new Date!.get-full-year!} Pipend Inc."

            # RIGHT SIDE
            div class-name: \queries-container,

                div class-name: "controls#{if !!@state.shadow then ' shadow' else ''}", 

                    div class-name: \title, "Queries"

                    # QUERY SEARCH CONTAINER (for icon font)
                    div class-name: "search-container#{if @state.expand-search then ' expanded' else ''}",

                        # QUERY SEARCH INPUT
                        input do
                            id: \query-search
                            placeholder: 'Search'
                            type: \text
                            value: query-title-search
                            on-change:({current-target: {value}}) ~> @set-state {query-title-search: value}
                            on-focus: ~> @set-state expand-search: true
                            on-blur: ~> @set-state expand-search: false

                # LIST OF QUERIES
                div do
                    id: \queries
                    class-name: \queries
                    on-scroll: ({current-target}) ~> 
                        if !@state.shadow and current-target.scroll-top > 0
                            @set-state shadow: true

                        if @state.shadow and current-target.scroll-top == 0
                            @set-state shadow: false

                    branches 
                        |> filter ({latest-query:{query-title}}) -> (query-title-search.length == 0) or (query-title.to-lower-case!.index-of query-title-search.to-lower-case!) != -1
                        |> filter ({latest-query:{tags or []}}) -> (selected-tags.length == 0) or (tags |> any ~> it in selected-tags)                        
                        |> map ({branch-id, latest-query:{query-id, query-title, tags or []}, snapshot}?) ->

                            # QUERY
                            Link do
                                id: \query
                                class-name: \query
                                key: query-id
                                to: "/branches/#{branch-id}/queries/#{query-id}" 

                                # THUMBNAIL
                                div do 
                                    class-name: \thumbnail
                                    style: 
                                        background-image: "url(#{snapshot})"

                                # INFO
                                div class-name: \info,
                                    div class-name: \title, query-title
                                    div class-name: \tags,
                                        tags |> map (tag) ~>
                                            span do 
                                                key: tag
                                                class-name: "tag #{if tag in selected-tags then 'selected' else ''}"
                                                tag
    
    # get-initial-state :: a -> UIState
    get-initial-state: -> 
        branches: []
        shadow: false
        expand-search: false
        tags: []
        selected-tags: []
        tag-search: ""
        query-title-search: ""

    # component-did-mount :: a -> Void
    component-did-mount: !->
        document.title = 'Queries'
        $.get \/apis/branches, (branches) ~> @set-state do
            branches: branches
            tags: branches 
                |> concat-map -> it?.latest-query?.tags or []
                |> unique
                |> sort