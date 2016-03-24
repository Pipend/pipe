$ = require \jquery-browserify

# prelude
{filter, map, pairs-to-obj, sum} = require \prelude-ls

{create-class, create-factory, DOM:{div}}:React = require \react
{find-DOM-node} = require \react-dom
AceEditor = create-factory require \./AceEditor.ls

module.exports = create-class do

    # get-default-props :: () -> Props
    get-default-props: ->
        /*
        Editor :: {
            name :: String
            content :: String
            height :: Int
            render-title: () -> ReactElement
            ace-editor-props: object
        }
        */
        editors: [] # [Editor]
        style: 
            width: 300
            height: 700

    # render :: () -> ReactElement
    render: ->
        div do 
            class-name: \resizeable-editor-group
            style: @props.style
            [0 til @props.editors.length] |> map (i) ~>

                # :: Editor
                {
                    name
                    render-title
                    content
                    height
                    ace-editor-props
                    show-title
                    show-content
                }? = @props.editors[i]

                # EDITOR
                div do 
                    class-name: \title-and-editor
                    key: name

                    if show-title

                        # TITLE
                        div do 
                            id: "#{name}Title"
                            class-name: \title
                            on-mouse-down: (e) ~>
                                y = e.page-y
                                editors = Array.prototype.slice.call @props.editors

                                $ window .on \mousemove, ({pageY}) ~> 
                                    diff = page-y - y
                                    previous-editor = editors[i - 1]
                                    current-editor = editors[i]
                                    @props.on-height-change do 
                                        "#{previous-editor.name}EditorHeight" : previous-editor.height + diff
                                        "#{current-editor.name}EditorHeight" : current-editor.height - diff

                                $ window .on \mouseup, -> 
                                    $ window 
                                        .off \mousemove 
                                        .off \mouseup

                            render-title!

                    if show-content

                        # ACE EDITOR
                        AceEditor do 
                            {
                                editor-id: "#{name}Editor"
                                value: content
                                style:
                                    width: @props.style.width
                                    height: height
                                on-change: (value) ~> 
                                    @props.on-content-change "#{name}" : value
                            } <<< ace-editor-props

    # component-did-mount :: () -> ()
    component-did-mount: !->
        visible-editors = @props.editors |> filter (.show-content)
        occupied-height = visible-editors 
            |> map (.height ? 0) 
            |> sum
        editors-with-title = @props.editors |> filter (.show-title)
        available-height = @props.style.height - occupied-height - (30 * editors-with-title.length)
        editors-without-height = @props.editors |> filter ({height}?) -> typeof height == \undefined
        @props.on-height-change do
            editors-without-height 
                |> map ({name}) ->
                    ["#{name}EditorHeight", (available-height / editors-without-height.length)]
                |> pairs-to-obj

    # component-did-update :: Props -> UIState -> ()
    component-did-update: (prev-props) !->
        [visible-before, visible-now] = [prev-props, @props] |> map ({editors}) ->
            editors |> filter (.show-content)

        # if visible-now < visible-before

        # else if visible-now > visible-before

