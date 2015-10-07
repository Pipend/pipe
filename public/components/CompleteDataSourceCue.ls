{create-factory, DOM:{div}}:React = require \react
LabelledTextField = create-factory require \./LabelledTextField.ls
SimpleButton = create-factory require \./SimpleButton.ls
{map} = require \prelude-ls

# :: [String] -> CompleteDataSourceCue 
module.exports = (fields) ->

    React.create-class do

        display-name: \CompleteDataSourceCue

        # get-default-props :: a -> Props
        get-default-props: ->
            # on-change :: DataSourceCue -> Void
            # data-source-cue :: DataSourceCue
            {}

        # render :: a -> ReactElement
        render: ->
            div class-name: 'complete data-source-cue',
                
                # INPUT FIELDS
                fields |> map (key) ~>
                    LabelledTextField do
                        key: key
                        label: key
                        value: @props.data-source-cue?[key] or ""
                        on-change: (value) ~> 
                            @props.on-change {} <<< @props.data-source-cue <<< {"#{key}": value, complete: false}

                # APPLY BUTTON
                SimpleButton do
                    pressed: @props.data-source-cue.complete
                    on-click: ~> @props.on-change {} <<< @props.data-source-cue <<< {complete:true}
                    \Apply
