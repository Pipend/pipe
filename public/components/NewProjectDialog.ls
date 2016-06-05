{map} = require \prelude-ls
{DOM:{div}, create-class, create-factory} = require \react
DataSourceCuePopup = create-factory require \./DataSourceCuePopup.ls
LabelledDropdown = create-factory require \./LabelledDropdown.ls
SimpleButton = create-factory require \./SimpleButton.ls
LabelledTextField = create-factory require \./LabelledTextField.ls
AceEditor = create-factory require \./AceEditor.ls

module.exports = create-class do 
    render: ->
        console.log \NewProjectDialog
        div do
            null
            LabelledTextField do
                label: 'Project Name'
                value: @props.project.title or ""
                on-change: (value) ~> 
                    @props.on-change {} <<< @props.project <<< title: value
            
            LabelledDropdown do
                label: 'Permissions'
                value: @props.project.permission
                options: <[private publicReadable publicExecutable publicReadableAndExecutable]> |> map -> {label: it, value: it}
                on-change: (value) ~>
                    @props.on-change {} <<< @props.project <<< permission: value
                    
            div style: {width: 400, height: 400}, AceEditor do
                editor-id: \connections-editor
                style: width: 400, height: 400
                # if @state.connections-json is not null, use this, otherwise use @props
                value: @state.connections-json ? JSON.stringify @props.project.connections, null, 4
                on-change: (value) ~> 
                    try 
                        @props.on-change {} <<< @props.project <<< connections: JSON.parse value
                        @set-state connections-json: null
                    catch ex
                        @set-state connections-json: value
                    
                    
    # get-initial-state :: a -> UIState
    get-initial-state: ->  
        # because the input json in the box is not always valid, use this to store invalid json
        connections-json: null