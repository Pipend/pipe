{DOM:{div}}:React = require \react
LabelledTextField = require \./LabelledTextField.ls
SimpleButton = require \./SimpleButton.ls
{map} = require \prelude-ls

module.exports = (fields) ->
    React.create-class do
        render: ->
            div {class-name: 'complete data-source-cue'},
                fields |> map (key) ~>
                    React.create-element do
                        LabelledTextField
                        key: key
                        label: key
                        value: @.props.data-source-cue?[key] or ""
                        on-change: (value) ~> 
                            @.props.on-change {} <<< @.props.data-source-cue <<< {"#{key}": value, complete: false}
                React.create-element do 
                    SimpleButton
                    label: \Apply
                    pressed: @props.data-source-cue.complete
                    on-click: ~> @props.on-change {} <<< @props.data-source-cue <<< {complete:true}

