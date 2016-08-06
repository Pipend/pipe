{concat-map, map, filter} = require \prelude-ls

alphabet = [String.from-char-code i for i in [65 to 65+25] ++ [97 to 97+25]]


# takes a collection of keyscores & maps them to {name, value, score, meta}
# convert-to-ace-keywords :: [{keywords: [String], score: Int}] -> String -> String -> [{name, value, score, meta}]
convert-to-ace-keywords = (keyscores, meta, prefix) ->
    keyscores |> concat-map ({keywords, score}) ->
        keywords
        |> filter (-> if !prefix then true else  (it.index-of prefix) == 0)
        |> map (text) ->
            name: text
            value: text
            meta: meta
            score: score


# ajax-keywords :: project-id -> [DataSourceCue, String] -> p [String]
export ajax-keywords = (project-id, source-and-language) ->
    new Promise (resolve, reject) ->
        $.ajax do
            type: \post
            url: "/apis/projects/#{project-id}/keywords"
            content-type: 'application/json; charset=utf-8'
            data-type: \json
            data: JSON.stringify source-and-language
            error: (error) ~>
                console.error "Error in /api/keywords AJAX", error
                reject error
            success: (data) ~>
                resolve data

# on-api-keywords-feteched :: keywords -> Promise static # static :: {keywords :: [String], ...}
# on-query-changed :: Query -> (Promise static) -> Promise ast
# get-completions :: Token -> Promise (static, ast) -> Promise completions
# make-auto-completer :: project-id -> (AceEditor -> Boolean) -> [DataSourceCue, String] -> ... -> p {on-query-changed :: String -> p AST, get-completions :: AceEditorMethod}
export make-auto-completer = (project-id, filter-function, [data-source-cue, transpilation-language], on-api-keywords-feteched, on-query-changed, get-completions) ->

    # get the keywords (name of tables, databases, query language related commands) from api
    {keywords}:api-keywords <- ajax-keywords project-id, [data-source-cue, transpilation-language] .then

    # get the name of different entities (like tables, collections etc) from api-keywords
    schema <- on-api-keywords-feteched api-keywords .then

    ast = null

    Promise.resolve do

        # build the AST i.e find out the tables, aliases used in the query using (keywords & entity names)
        # this function must be invoked everytime the query changes
        # on-query-changed :: String -> p AST
        on-query-changed: (query) ->
            new Promise (resolve, reject) ->
                (on-query-changed query, {schema, keywords})
                    .then (ast_) -> ast := ast_
                    .catch (err) -> # eat the error

        # method required by AceEditor for custom autocompletions, the implementation invokes the callback
        # with a list of keywords to be displayed
        get-completions: (editor, , , prefix, callback) ->
            range = editor.getSelectionRange!.clone!
                ..set-start range.start.row, 0
            text = editor.session.get-text-range range
            if filter-function editor
                custom-completions <- (get-completions text, {schema, keywords, ast}).then
                auto-complete = [keywords: keywords, score: 10] ++ [keywords: alphabet, score: 0] ++ custom-completions
                callback null, (convert-to-ace-keywords auto-complete, 'server', prefix)

# make-auto-completer-default :: (AceEditor -> Boolean) -> [DataSourceCue, String] -> p {on-query-changed :: String -> p AST, get-completions :: AceEditorMethod}
export make-auto-completer-default = (project-id, filter-function, source-and-language) ->
    make-auto-completer do
        project-id
        filter-function
        source-and-language
        ({keywords}:data) ->
            Promise.resolve null
            # do nothing
        (query, {keywords, schema}) ->
            Promise.resolve null
            # do nothing!
        (text, {schema, keywords, ast}) ->
            Promise.resolve []
