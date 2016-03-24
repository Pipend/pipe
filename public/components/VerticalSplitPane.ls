$ = require \jquery-browserify
{clone-element, create-class, DOM:{div}} = require \react

module.exports = create-class do

    # get-default-props :: () -> Props
    get-default-props: ->
        on-width-of-first-child-change: (->) # Int -> ()
        width-of-first-child: 0
        style: {}

    # render :: () -> ReactElement
    render: ->
        resize-handle-width = 5

        div do 
            class-name: \vertical-split-pane
            style: @props.style

            # FIRST CHILD
            clone-element do 
                @props.children.0
                style: {} <<< @props.children.0.props.style <<<
                    width: @props.width-of-first-child
                    height: @props.style.height

            # RESIZE HANDLE
            div do
                class-name: \resize-handle 
                style:
                    width: resize-handle-width
                on-mouse-down: ({page-x}) ~>
                    x = page-x
                    width-of-first-child = @props.width-of-first-child
                    
                    $ window .on \mousemove, ({page-x}) ~> 
                        @props.on-width-of-first-child-change width-of-first-child + (page-x - x)
                        
                    $ window .on \mouseup, -> 
                        $ window 
                            .off \mousemove 
                            .off \mouseup

            # SECOND CHILD
            clone-element do 
                @props.children.1
                style: 
                    left: @props.width-of-first-child + resize-handle-width
                    width: @props.style.width - (@props.width-of-first-child + resize-handle-width)
                    height: @props.style.height