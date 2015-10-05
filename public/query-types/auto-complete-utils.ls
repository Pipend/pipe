{concat-map, map, filter} = require \prelude-ls

alphabet = [String.from-char-code i for i in [65 to 65+25] ++ [97 to 97+25]]


# takes a collection of keyscores & maps them to {name, value, score, meta}
# [{keywords: [String], score: Int}] -> String -> String -> [{name, value, score, meta}]
convert-to-ace-keywords = (keyscores, meta, prefix) ->
    keyscores
        |> concat-map ({keywords, score}) -> 
            keywords 
            |> filter (-> if !prefix then true else  (it.index-of prefix) == 0)
            |> map (text) ->
                name: text
                value: text
                meta: meta
                score: score


export ajax-keywords = (data-source-cue) ->
    promise = new Promise (resolve, reject) ->
        $.ajax do
            type: \post
            url: "/apis/keywords"
            content-type: 'application/json; charset=utf-8'
            data-type: \json
            data: JSON.stringify data-source-cue
            error: (error) ~>
                console.error "Error in /api/keywords AJAX", error
                reject error
            success: (data) ~>
                resolve data

export make-pending-completer = ->
    {
        on-query-changed: (query) ->
            console.warn 'auto-complete is not ready yet'
        get-completions: (editor, , , prefix, callback) ->
            console.warn 'auto-complete is not ready yet'
            callback null, []
    }

export make-auto-completer = (data-source-cue, on-server-keywords-feteched, on-query-changed, get-completions) ->

    result = make-pending-completer!

    ajax-keywords data-source-cue .then ({keywords}:data) ~>
        on-server-keywords-feteched data

        result.on-query-changed = (query) ->
            on-query-changed query, data

        result.get-completions = (editor, , , prefix, callback) ->
            range = editor.getSelectionRange!.clone!
                ..set-start range.start.row, 0
            text = editor.session.get-text-range range
            if editor.container.id == \query-editor
                auto-complete = [keywords: keywords, score: 1] ++ [keywords: alphabet, score: 0] ++ (get-completions text, data)

                callback null, (convert-to-ace-keywords auto-complete, 'server', prefix)    

    result