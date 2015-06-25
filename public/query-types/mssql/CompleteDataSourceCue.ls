{DOM:{div, input, label}}:React = require \react
LabelledTextField = require \../../components/LabelledTextField.ls
{map} = require \prelude-ls

module.exports = React.create-class {

    render: ->
        div {class-name: 'mssql complete data-source-cue'},
            <[server user password database]> |> map (key) ~>
                React.create-element do
                    LabelledTextField
                    key: key
                    label: key
                    value: @.props.data-source-cue?[key] or ""
                    on-change: (value) ~> 
                        @.props.on-change {} <<< @.props.data-source-cue <<< {"#{key}": value, complete: false}
            div do
                {
                    style:
                        background: if @props.data-source-cue.complete then \green else \red 
                    on-click: ~> @props.on-change {} <<< @props.data-source-cue <<< {complete:true}
                }
                \complete
}