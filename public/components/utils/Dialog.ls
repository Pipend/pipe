{create-class, create-factory, DOM:{button, div, h1, label, input, a, span, select, option}}:React = require \react
SimpleButton = create-factory require \./../SimpleButton.ls

# example: SettingsDialog

module.exports = ({component, class-name, title, save-label, cancel-label, on-save, on-cancel}) ->
    div class-name: "dialog #{class-name}",
        # TITLE
        div class-name: \header, title

        component

        # OK / CANCEL
        div class-name: \footer,
            SimpleButton do
                class-name: "save"
                color: \grey
                on-click: ~> on-save!
                save-label
            SimpleButton do
                class-name: "cancel"
                color: \grey
                on-click: ~> on-cancel!
                cancel-label
