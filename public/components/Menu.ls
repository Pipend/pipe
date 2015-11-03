{create-class, create-factory, DOM:{a, div, input}}:React = require \react
{find-DOM-node} = require \react-dom
Checkbox = create-factory require \./Checkbox.ls
{difference, each, filter, map, unique, sort} = require \prelude-ls
{key} = require \keymaster
{cancel-event} = require \../utils.ls

module.exports = React.create-class do

    display-name: \Menu

    # get-default-props :: a -> Props
    get-default-props: ->
        items: [] # [{pressed :: Boolean, enabled :: Boolean, action :: (->), hotkey :: String, label :: String, highlight :: Boolean, type :: String}]

    # render :: a -> ReactElement
    render: ->
        div do 
            id: \menu
            class-name: \menu

            # CHILDREN (logo)
            @props.children

            # BUTTONS
            div do 
                class-name: \buttons
                @props.items |> map ({pressed, enabled, href, action, hotkey, label, highlight, type}:item) ~>

                    # using ref for accessing the anchor tag from action listener
                    ref = label.replace /\s/g, \- .to-lower-case!
                    
                    # action-listener :: Event -> Boolean
                    action-listener = (e) ~>
                        set-timeout do 
                            ~>
                                {offset-left, offset-width}:anchor-tag = find-DOM-node @refs[ref]
                                action offset-left, offset-width
                            0
                        cancel-event e

                    # connect the action-listener to hotkey
                    if !!hotkey
                        key.unbind hotkey
                        if enabled
                            key hotkey, action-listener 
                    
                    # MENU ITEM
                    a do 
                        {
                            id: ref
                            class-name: if pressed then \pressed else ''
                            key: ref
                            ref: ref
                            style: 
                                border-top: if !!highlight then "1px solid #{highlight}"  else ""
                                opacity: if !enabled then 0.5 else 1
                        } <<< (

                            # (href, target: blank) has higher precedence over on-click
                            # popup blocker does not like window.open
                            if enabled
                                
                                if !!href
                                    href: href
                                    target: \_blank
                                    
                                else
                                    on-click: action-listener

                            else
                                {}
                        )

                        # CHECKBOX
                        match type
                            | \toggle => React.create-element Checkbox, {checked: item.toggled}

                        # ITEM TEXT
                        label
                        
    # remove key listener for deleted menu items
    # component-will-receive-props :: Props -> Void
    component-will-receive-props: (props) !->

        # get-hotkeys :: Props -> [String]
        get-hotkeys = ({items}) -> 
            (items or [])
                |> filter -> !!it?.hotkey
                |> map (.hotkey)
                |> unique
                |> sort

        (get-hotkeys @props) `difference` get-hotkeys props
            |> each key.unbind
