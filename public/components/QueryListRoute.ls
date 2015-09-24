require! \./AceEditor.ls
$ = require \jquery-browserify
{any, concat-map, filter, map, partition, unique, sort} = require \prelude-ls
{DOM:{a, div, img, input, span}}:React = require \react
{compile-and-execute-livescript} = require \../utils.ls

module.exports = React.create-class do

    display-name: \QueryListRoute

    # render :: a -> ReactElement
    render: ->
        {branches, tags, selected-tags, tag-search, query-title-search} = @state
        
        div class-name: \query-list-route,

            # LEFT SIDE MENU
            div class-name: \menu,

                # NEW QUERY BUTTON
                a {href: "branches", target: \_blank}, 'New query'

                # LIST OF SELECTED TAGS
                div do 
                    class-name: \selected-tags
                    selected-tags.to-string!                

                # TAG SEARCH INPUT
                input do 
                    type: \text
                    value: tag-search
                    placeholder: 'Search for tags...'
                    on-change:({current-target:{value}}) ~> @set-state {tag-search: value}

                # LIST OF TAGS
                div do 
                    class-name: \tags
                    tags 
                        |> filter (tag) -> (tag-search.length == 0) or ((tag.to-lower-case!.index-of tag-search.to-lower-case!) != -1)
                        |> map (tag) ~>
                            selected = tag in selected-tags
                            div do
                                class-name: "tag #{if selected then 'selected' else ''}"
                                on-click: ~> 
                                    @set-state do 
                                        selected-tags: 
                                            | selected => selected-tags |> partition (== tag) |> (.1)
                                            | _ => [tag] ++ selected-tags
                                tag

            div class-name: \queries-container,

                # QUERY TITLE SEARCH INPUT
                input do 
                    type: \text
                    value: query-title-search
                    placeholder: 'Search for queries...'
                    on-change:({current-target: {value}}) ~> @set-state {query-title-search: value}

                # LIST OF QUERIES
                div {class-name: \queries},
                    branches 
                        |> filter ({latest-query:{query-title}}) -> (query-title-search.length == 0) or (query-title.to-lower-case!.index-of query-title-search.to-lower-case!) != -1
                        |> filter ({latest-query:{tags or []}}) -> (selected-tags.length == 0) or (tags |> any ~> it in selected-tags)                        
                        |> map ({branch-id, latest-query:{query-id, query-title, tags or []}, snapshot}?) ->
                            div {class-name: \query},
                                img {src: snapshot}
                                a do 
                                    href: "branches/#{branch-id}/queries/#{query-id}" 
                                    query-title
                                div {class-name: \tags},
                                    tags |> map (tag) ->
                                        span {class-name: "tag #{if tag in selected-tags then 'selected' else ''}"}, tag
    
    # get-initial-state :: a -> UIState
    get-initial-state: -> 
        branches: []
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