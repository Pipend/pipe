{filter, map} = require \prelude-ls
{create-class, create-factory, DOM:{a, div, label, span}}:React = require \react

module.exports = create-class do 

    # get-default-props :: () -> Props
    get-default-props: ->
        /*
        Status ::
            title :: String
            value :: a
        Button ::
            href :: String
            title :: String
        */
        statuses: [] # :: [Status]
        buttons: [] # :: [Button]

    # render :: () -> ReactElement
    render: ->
        div class-name: \status-bar,

            div class-name: \statuses,
                @props.statuses 
                    |> filter (.show)
                    |> map ({title, value}) ->

                        # STATUS
                        div do 
                            class-name: \status
                            key: title
                            label null, title
                            span null, value

            div class-name: \buttons,
                @props.buttons |> map ({href, title}) ->

                    # BUTTON
                    a do 
                        class-name: \button
                        key: title
                        href: href
                        title