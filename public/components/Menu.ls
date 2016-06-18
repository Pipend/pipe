{difference, each, filter, map, unique, sort} = require \prelude-ls
{key} = require \keymaster
{create-class, create-factory, DOM:{a, div, input}}:React = require \react
{find-DOM-node} = require \react-dom
require! \react-router
Link = create-factory react-router.Link
Checkbox = create-factory require \./Checkbox.ls
{cancel-event} = require \../lib/utils.ls

module.exports = React.create-class do

    display-name: \Menu

    # get-default-props :: a -> Props
    get-default-props: ->
        on-logo-click: (->)
        /*
        MenuItem ::
            pressed :: Boolean
            disabled :: Boolean
            action :: (->)
            hotkey :: String
            label :: String
            highlight :: Boolean
            type :: String
        */
        items-left: [] # [MenuItem]
        items-right: [] # [MenuItem]

    # render :: a -> ReactElement
    render: ->
        div do 
            id: \menu
            class-name: \menu

            # LOGO
            Link do 
                id: \logo
                class-name: \logo
                to: \/

            # MENU ITEMS
            div class-name: 'buttons left',
                @props.items-left |> map @render-item

            # MENU ITEMS
            div class-name: 'buttons righ',
                @props.items-right |> map @render-item
            
            # USER
            div class-name: \user

    # TODO: use a proper sum type for menu items
    render-item: ({pressed, disabled, href, action, hotkey, label, text, highlight, type, toggled}) ->
        
        # using ref for accessing the anchor tag from action listener
        ref = label.replace /\s/g, \- .to-lower-case!
        
        match type
        | \textbox => do ~>
            input { 
                id: ref
                ref: ref
                key: ref
                type: \text
                disabled: disabled
                value: text
                on-change: (e) -> action e.target.value 
            }
        | _ => do ~>
            # action-listener :: Event -> Boolean
            action-listener = (e) ~>
                set-timeout do 
                    ~>
                        {offset-left, offset-width}:anchor-tag = find-DOM-node @refs[ref]
                        action offset-left, offset-width
                    0
                cancel-event e
    
            # connect the action-listener to hotkey
            if hotkey
                key.unbind hotkey
                if !disabled
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
                        opacity: if disabled then 0.5 else 1
                } <<< (
    
                    # (href, target: blank) has higher precedence over on-click
                    # popup blocker does not like window.open
                    if disabled
                        {}
    
                    else
                        if href
                            href: href
                            target: \_blank
                            
                        else
                            on-click: action-listener
                )
    
                # CHECKBOX
                match type
                    | \toggle => React.create-element Checkbox, {checked: toggled}
    
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
