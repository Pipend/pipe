{create-factory, DOM:{div, h1, table, input, form, button, a, span, label}}:React = require \react
ace-language-tools = require \brace/ext/language_tools 
AceEditor = create-factory require \./AceEditor.ls
ace-language-tools = require \brace/ext/language_tools 
Menu = create-factory require \./Menu.ls
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

            Menu do 
                ref: \menu
                items: do ~>
                    a = 
                        * label: \Parse
                          icon: \e
                          enabled: true
                          hotkey: "command + enter"
                          show: true
                          action: ~>
                            @action_parse!
                        * label: \...
                    |> filter ({show}) -> (typeof show == \undefined) or show
                a class-name: \logo, href: \/

            div do
                {
                    style: display: \flex
                    class-name: "content"
                }

                div do 
                    {
                        class-name: \editors
                    }

                    div { class-name: \editor-title }, "Import a file"
                    div {},
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
                                    .reduce1 (a, b) -> "#a\n#b"
                                    .each (d) ~>
                                        @set-state {
                                            status: "file-selected"
                                            console: d, 
                                            message: "Your file (#{file.name}; #{file.type}) is #{d3.format ',' <| file.size} bytes. " + 
                                                if file.size >= (10*1024) then "Here's its first 10 kilobytes:" else "Here it is:"
                                            transformation: do ->
                                                if transformation in Obj.values default-transformations
                                                    default-transformations[file.type] ? default-transformations["_"]
                                                else
                                                    transformation
                                        }
                                    .done "end", ->
                                        st.close!
                        }, null
                        div { class-name: \editor-title }, "Parser:"
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
                        
                        div { class-name: \editor-title }, "Select a destination"
                        div do 
                            {
                            }
                            DataSourceCuePopup do
                                left: -> 0
                                data-source-cue: @state.data-source-cue
                                on-change: (data-source-cue) ~> 
                                    <~ @set-state {data-source-cue}
                                    save-to-client-storage @state
                        button {
                            type: \submit
                            class-name: "simple-button"
                            disabled: "file-parsed" != @state.status
                            on-click: (e) ~>
                                form-data = new FormData!

                                {file, data-source-cue, transformation} = @state

                                if !!file 

                                    debugger
                                    doc = 
                                        data-source-cue: data-source-cue
                                        parser:
                                            transformation


                                    form-data.append "doc", JSON.stringify doc
                                    form-data.append "file", file

                                    @set-state {status: "uploading", upload-progress: 0}
                                    xhr = new XMLHttpRequest!
                                        ..open 'POST', "/apis/queryTypes/mongodb/import", true
                                        ..onload = (e) ~>
                                            switch 
                                            | 200 == xhr.status =>
                                                @set-state {
                                                    status: "done"
                                                    server-message: 
                                                        message: do ->
                                                            res = JSON.parse xhr.responseText
                                                            "#{d3.format ',' <| res.inserted} records inserted"
                                                        type: "success"
                                                }
                                            | otherwise =>
                                                @set-state {
                                                    status: "error"
                                                    server-message: 
                                                        message: xhr.responseText
                                                        type: "error"
                                                    upload-progress: 1
                                                }
                                            
                                        ..onerror = (e) ~>
                                            @set-state {status: "error", message: "Unhandled error"}
                                            
                                        ..upload.onprogress = (e) ~>
                                            progress = e.loaded / e.total
                                            @set-state {
                                                upload-progress: progress
                                                status: if progress < 0.9 then "uploading" else "importing"
                                            } <<< if progress = 1 then {server-message: {message: "Importing...", type: "info"}} else {}
                                        ..send form-data
                                else
                                    @set-state {status: "error", message: "Please select a file"}


                                e.stop-propagation!
                                e.prevent-default!
                        }, "Upload!"
                        div {
                            class-name: "server-message #{@state.server-message?.type}"
                        }, @state.server-message?.message
                        Progress {
                            progress: @state.upload-progress
                            error: "error" == @state.status
                            height: 10
                        }

                div do
                    class-name: \resize-handle
                    ""
                div do
                    {
                        class-name: "presentation-container"
                    }
                    div {class-name: "message"}, @state.message
                    div {class-name: "raw console"}, @state.console
            
                    if @state.error then div {class-name: "parsed console error"}, @state.error else div {class-name: "parsed console"}, (@state.parsed ? []).map (p) ->
                        div { }, p
                    div do 
                        {
                            class-name: "status-bar"
                        }
                        do ~>
                            items = 
                                * title: 'Status'
                                  value: @state.status
                                ...
                            items
                            |> map ({title, value}) -> 
                                div null, 
                                    label null, title
                                    span null, value


            


        
    component-did-mount: -> 

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
            message: null
            console: null
            server-message: null
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
            upload-progress: 0
            error: null
            status: "initial" # inital | file-selected | file-parsed | uploading | importing | uploaded
        }

    action_parse: ->
        @set-state {parsed: [], error: null}

        {file, transformation} = @state

        if !file 
            @set-state {error: "Please first select a file.", status: "initial"}
            return 

        [err, transformationf] = compile-and-execute-livescript transformation, {JSONStream, highland, csv-parse} <<< (require \prelude-ls)
        if !!err
            @set-state {error: "Error in parsing the parser script.\n#{err.toString!}", status: "file-selected"}
            return


        st = readFile 1024, file
        try 
            reader = highland st
                .take 10
                .pipe transformationf
                .pipe highland.pipeline (s) ->
                    s
                        .map (o) -> JSON.stringify o, null, 4
                        .map (-> [it])
                        .reduce [], (++)
                        #.batch 10
                        #.take 1
                .stopOnError (err) ->
                    @set-state {error: "Error in parsing your file.\n#{err.toString!}", status: "file-selected"}
                .each (d) ~>
                    @set-state {parsed: d, status: "file-parsed"}
                .done ->
                    st.close!
        catch ex
            @set-state {error: "Error in parsing your file.\n#{ex.toString!}", status: "file-selected"}

}



Progress = create-factory do -> 
    
    last-update = null

    React.create-class {

        display-name: \Progress

        render: ->
            div do  
                {
                    style:
                        display: 'inline-block' # @state.display
                        position: 'fixed'
                        top: 0
                        left: 0
                        width: "#{@props.progress * 100}%"
                        maxWidth: '100% !important'
                        height: "#{@props.height}px"
                        boxShadow: '1px 1px 1px rgba(0,0,0,0.4)'
                        borderRadius: '0 1px 1px 0'
                        WebkitTransition: "#{@state.speed}s width, #{@state.speed}s background-color" + if @props.progress == 1 then ", #{3}s opacity" else ""
                        transition: "#{@state.speed}s width, #{@state.speed}s background-color" + if @props.progress == 1 then ", #{3}s opacity" else ""
                        background-image:  if @props.error then 'linear-gradient(to right, #D1D94C, #E09A32, #C79616, #F17F1D, #E46019, #FF2D55)' else 'linear-gradient(to right, #4cd964, #5ac8fa, #007aff, #34aadc, #5856d6, #FF2D55)'
                        background-size: "100vw #{@props.height}px"
                        opacity: if @props.progress == 1 then 0 else 1
                    title: d3.format "%" <| @props.progress
                }

        component-will-receive-props: (props) !->
            return if !props.progress

            now = new Date!.valueOf!
            if last-update != null
                speed = (now - last-update) / 1000
                @set-state {speed: speed, display: 'inline-block'}
            else
                @set-state {display: 'inline-block'}
            last-update := now

            if props.progress == 1
                last-update := null
                <~ set-timeout _, 3000
                @set-state {display: 'none', speed: 0}


        get-initial-state: ->
            speed: 0
            display: 'inline-block'

    }