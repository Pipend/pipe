{create-factory, DOM:{div, h1, table, input, form, button}}:React = require \react
ace-language-tools = require \brace/ext/language_tools 
AceEditor = create-factory require \./AceEditor.ls
ace-language-tools = require \brace/ext/language_tools 
DataSourceCuePopup = create-factory require \./DataSourceCuePopup.ls
{all, any, camelize, concat-map, dasherize, difference, each, filter, find, keys, is-type, 
last, map, sort-by, sum, round, obj-to-pairs, pairs-to-obj, take, unique, unique-by, Obj} = require \prelude-ls
$ = require \jquery-browserify
client-storage = require \../client-storage.ls
{is-equal-to-object, compile-and-execute-livescript} = require \../utils.ls
{readFile, readMinNBytes, readNLines, readTakeN} = require \../lazy-file-reader.ls
csv-parse = require \csv-parse
JSONStream = require "JSONStream"
highland = require "highland"

save-to-client-storage = (state) ->
    client-storage.save-document "import-data-source-cue", state.data-source-cue
load-from-client-storage = (state) ->
    if !state.data-source-cue
        state.data-source-cue = (client-storage.get-document "import-data-source-cue") ? {query-type: \mongodb, kind: \partial-data-source, complete: false}
    state

# copied from QueryRoute.ls \\//

# returns dasherized collection of keywords for auto-completion
keywords-from-object = (object) ->
    object
        |> keys 
        |> map dasherize

# takes a collection of keywords & maps them to {name, value, score, meta}
convert-to-ace-keywords = (keywords, meta, prefix) ->
    keywords
        |> map -> {text: it, meta}
        |> filter -> (it.text.index-of prefix) == 0 
        |> map ({text, meta}) -> {name: text, value: text, score: 0, meta}

alphabet = [String.from-char-code i for i in [65 to 65+25] ++ [97 to 97+25]]
# copied from QueryRoute.ls //\\

module.exports = React.create-class {

    display-name: \ImportRoute

    render: ->

        div {class-name: "import-route #{@state.state}"},
            h1 {}, "Import"

            div {
                style: 
                    position: \relative
                    height: \250px
            },
                DataSourceCuePopup do
                    left: -> 0
                    data-source-cue: @state.data-source-cue
                    on-change: (data-source-cue) ~> 
                        <~ @set-state {data-source-cue}
                        save-to-client-storage @state
            form {},
                input {
                    type: \file
                    on-change: (e) ~>
                        file = e.target.files[0]
                        {transformation, default-transformations} = @state
                        @set-state {file}
                        st = readFile 1024, file
                        reader = highland st
                            .take 10
                            .split!
                            .take 10
                            .reduce1 (a, b) -> "#a\n#b"
                            .each (d) ~>
                                @set-state {
                                    console: d, 
                                    message: "Your file (#{file.name}; #{file.type}) is #{d3.format ',' <| file.size} bytes, here's the first 10 byte or first 10 lines:"
                                    transformation: do ->
                                        if transformation in Obj.values default-transformations
                                            default-transformations[file.type] ? default-transformations["_"]
                                        else
                                            transformation
                                }
                            .done "end", ->
                                console.log "reader ended"
                                st.close!
                }, null
                div {class-name: "message"}, @state.message
                div {class-name: "console"}, @state.console
                div do
                    { 
                        class-name: 'import-editor'
                        style: position: \relative
                        key: "import-editor"
                    }
                    AceEditor do
                        editor-id: "import-editor"
                        value: @state.transformation
                        width: '400'
                        height: 300
                        on-change: (value) ~> 
                            <~ @set-state transformation : value
                            #@save-to-client-storage-debounced!
                button {
                    on-click: (e) ~>
                        e.stop-propagation!
                        e.prevent-default!

                        @set-state {parsed: []}

                        {file, transformation} = @state

                        [err, transformationf] = compile-and-execute-livescript transformation, {JSONStream, highland, csv-parse} <<< (require \prelude-ls)
                        if !!err
                            alert err.toString!
                            return


                        st = readFile 1024, file
                        reader = highland st
                            .take 10
                            .pipe transformationf
                            .pipe highland.pipeline (s) ->
                                s
                                    .map (o) -> JSON.stringify o, null, 4
                                    .batch 10
                                    .take 1
                            .each (d) ~>
                                console.log d
                                @set-state {parsed: d}
                            .done ->
                                console.log "done"
                                st.close!


                }, "Parse (Preview)"
                button {
                    type: \submit
                    disabled: "uploading" == @state.state
                    on-click: (e) ~>
                        form-data = new FormData!

                        {file, data-source-cue} = @state

                        if !!file 

                            doc = 
                                document:
                                    data-source-cue: data-source-cue

                            form-data.append "doc", JSON.stringify doc
                            form-data.append "file", file

                            @set-state {state: "uploading"}
                            xhr = new XMLHttpRequest!
                                ..open 'POST', "/apis/queryTypes/mongodb/import", true
                                ..onload = (e) ~>
                                    switch 
                                    | 200 == xhr.status =>
                                        @set-state {state: "uploaded", message: xhr.responseText}
                                    | otherwise =>
                                        @set-state {state: "error", message: xhr.responseText}
                                    
                                ..onerror = (e) ~>
                                    @set-state {state: "error", message: "Unhandled error"}
                                    
                                ..send form-data
                        else
                            @set-state {state: "error", message: "Please select a file"}


                        e.stop-propagation!
                        e.prevent-default!
                }, "Upload!"
            div {class-name: "parsed console"}, (@state.parsed ? []).map (p) ->
                div { }, p

            


        
    component-did-mount: -> 
        console.log @.props

        do ->
            transformation-keywords = ([JSONStream, csv-parse, highland, (require \prelude-ls)] |> concat-map keywords-from-object) ++ alphabet
            @default-completers =
                * protocol: 
                    get-completions: (editor, , , prefix, callback) ~>
                        range = editor.getSelectionRange!.clone!
                            ..set-start range.start.row, 0
                        text = editor.session.get-text-range range
                        [keywords, meta] = match editor.container.id
                            | \import-editor => [transformation-keywords ++ alphabet, \transformation]
                            | _ => [alphabet, editor.container.id]
                        callback null, (convert-to-ace-keywords keywords, meta, prefix)
                ...
            ace-language-tools.set-completers (@default-completers |> map (.protocol))

    get-initial-state: -> 
        load-from-client-storage {
            state: "initial" # | uploading | uploaded | error
            message: null
            console: null
            parsed: []
            data-source-cue: null
            file: null
            default-transformations:
                "application/json": "JSONStream.parse '*'"
                "text/csv": """csv-parse {
                        comment: '#',
                        relax: true,
                        skip_empty_lines: true,
                        trim: true,
                        auto_parse: true,
                        columns: true
                    }"""
                "_": "highland.pipeline (s) -> \n    s.through JSONStream.parse '*'"
            transformation: "highland.pipeline (s) -> \n    s.through JSONStream.parse '*'"
        }

}