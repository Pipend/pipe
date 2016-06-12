{filter, find, map} = require \prelude-ls
{clone-element, create-class, DOM:{div}} = require \react

module.exports = create-class do

    # get-default-props :: () -> Props
    get-default-props: ->
        direction: \left
        height: 0
        /*
        Tab :: 
            title :: String
            component :: ReactElement
        */
        tabs: [] # :: [Tab]
        # active-tab-title :: String
        on-active-tab-title-change: (->) # String? -> ()
        style: {}

    # render :: () -> ReactElement
    render: ->
        active-tab-title = 
            | @props.has-own-property \activeTabTitle => @props.active-tab-title
            | _ => @state.active-tab-title

        div do 
            class-name: "vertical-nav #{@props.direction} #{if !!active-tab-title then 'open' else 'closed'}"
            style: @props.style

            # TABS
            div do 
                class-name: \tabs

                # height is passed to width because the tabs are rotated 90 degrees
                style:
                    width: @props.height

                @props.tabs |> map ({title}) ~>

                    # TAB
                    div do 
                        key: title
                        class-name: "tab #{if title == active-tab-title then \active else ''}"
                        on-click: ~>
                            new-active-tab-title = switch
                                | title == active-tab-title => undefined 
                                | _ => title

                            if @props.has-own-property \activeTabTitle
                                @props.on-active-tab-title-change new-active-tab-title

                            else
                                @set-state active-tab-title: new-active-tab-title
                            
                        title

                # PLACEHOLDER (for border effect)
                div class-name: \placeholder

            if active-tab-title

                # CONTENT CONTAINER
                div do 
                    class-name: \content-container
                    style: 
                        height: @props.height

                    # ACTIVE TAB COMPONENT
                    @props.tabs 
                        |> find ({title}) ~> title == active-tab-title
                        |> ({component}?) ~>
                            if component 
                                clone-element do 
                                    component
                                    style: {} <<< (component.props?.style ? {}) <<< 
                                        height: @props.height
                            else
                                null

    # get-initial-state :: () -> UIState
    get-initial-state: ->
        active-tab-title: undefined
