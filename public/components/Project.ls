{map} = require \prelude-ls
{create-class, create-factory, DOM:{a, div}}:React = require \react
require! \react-router
Link = create-factory react-router.Link

module.exports = create-class do

    display-name: \Project

    # get-default-props :: () -> Props
    get-default-props: ->
        title: ""
        permission: "" # :: publicReadable | private
        documents-link: ""

    # render :: () -> ReactElement
    render: ->
        div class-name: \project,

            if @props.permission == \private
                
                # LOCK
                div class-name: \lock

            div class-name: \description,

                # TITLE
                Link do
                    class-name: \title
                    to: @props.documents-link
                    @props.title

                div class-name: \buttons,

                    # CLONE
                    div do 
                        class-name: 'button clone'
                        on-click: ~>
                        \Clone

                    # SHARE
                    div do 
                        class-name: 'button share'
                        on-click: ~>
                        \Share

                # ROLE
                div class-name: \role, \owner

            div class-name: \stats