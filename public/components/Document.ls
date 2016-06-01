{filter, map} = require \prelude-ls
{create-class, create-factory, DOM:{div, img}}:React = require \react
require! \react-router
Link = create-factory react-router.Link
Document = create-factory require \./Document.ls
Menu = create-factory require \./Menu.ls

module.exports = create-class do

    display-name: \Document

    get-default-props: ->
        snapshot-url: ""
        document-link: ""
        title: ""
        last-saved-by: ""
        last-saved-on: ""

    # render :: a -> ReactElement
    render: ->
        div class-name: \document,

            # SNAPSHOT
            div class-name: \snapshot,
                img src: \/public/images/snapshot-placeholder.jpg

            # DESCRIPTION
            div class-name: \description,

                # TITLE
                Link do 
                    class-name: \title
                    to: @props.document-link
                    @props.title

                # LAST SAVED
                div class-name: \last-saved, 
                    div null, "Last saved by #{@props.last-saved-by}"
                    div null, @props.last-saved-on
