{map} = require \prelude-ls
{DOM:{div}, create-class, create-factory} = require \react
DataSourceCuePopup = create-factory require \./DataSourceCuePopup.ls
LabelledDropdown = create-factory require \./LabelledDropdown.ls
SimpleButton = create-factory require \./SimpleButton.ls

module.exports = create-class do 

    # get-default-props :: a -> Props
    get-default-props: ->
        initial-data-source-cue: {} # :: DataSourceCue
        initial-transpilation-language: ''
        on-create: (data-source-cue, transpilation-language) !-> # DataSourceCue -> String -> Void

    # render :: a -> ReactElement
    render: ->
        div do 
            class-name: 'new-query-dialog dialog'

            # TITLE
            div class-name: \header, "New Query"

            # DESCRIPTION
            div class-name: \description, 'Choose your prefered language and the data source to query'

            # TRANSPILATION LANGUAGE
            LabelledDropdown do 
                class-name: \language
                label: \Language
                options: <[javascript babel livescript]> |> map ~> label: it, value: it
                value: @state.transpilation-language
                on-change: (transpilation-language) ~> @set-state {transpilation-language}

            # DATASOURCE POPUP
            DataSourceCuePopup do
                data-source-cue: @state.data-source-cue
                left: -> 0
                on-change: (data-source-cue) ~> @set-state data-source-cue: {} <<< data-source-cue <<< complete: true

            div class-name: \footer,

                # OK
                SimpleButton do
                    id: \create-query
                    color: \grey
                    on-click: ~> @props.on-create do 
                        @state.data-source-cue
                        @state.transpilation-language
                    \Create

    # get-initial-state :: a -> UIState
    get-initial-state: ->
        data-source-cue: @props.initial-data-source-cue
        transpilation-language: @props.initial-transpilation-language