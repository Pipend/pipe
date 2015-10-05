CompleteDataSourceCue = (require \../../components/CompleteDataSourceCue.ls) <[server user password database]>
PartialDataSourceCue = require \./PartialDataSourceCue.ls

{concat-map, map, filter} = require \prelude-ls
sqlite-parser = require \sqlite-parser

# utils
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

# utils
ajax-keywords = (data-source-cue) ->
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

client-side-editor-settings = (transpilation-language) ->
    mode: "ace/mode/#{transpilation-language}"
    theme: \ace/theme/monokai

server-side-editor-settings =
    mode: \ace/mode/sql
    theme: \ace/theme/monokai

module.exports = {
    data-source-cue-popup-settings: ->
        supports-connection-string: true
        partial-data-source-cue-component: PartialDataSourceCue
        complete-data-source-cue-component: CompleteDataSourceCue
    query-editor-settings: (_) -> server-side-editor-settings
    transformation-editor-settings: (transpilation-language) -> 
        client-side-editor-settings transpilation-language
    presentation-editor-settings: (transpilation-language) -> 
        client-side-editor-settings transpilation-language
    make-auto-completer: (data-source-cue) ->

        result = {
            on-query-changed: (query) ->
                console.warn 'auto-complete is not ready yet'
            get-completions: (editor, , , prefix, callback) ->
                console.warn 'auto-complete is not ready yet'
                callback null, []
        }
        ajax-keywords.then ({keywords}:data) ~>
            #TODO: update mongodb and other DataSources
                
            # the type of data depends on the DataSourceCue.
            # but it always have a keywords prop: [String]

            # SQL \/
            # [['schema.table', 'table']]
            tables = data.tables |> Obj.keys |> concat-map (-> [it, it.split \. .1])
            schemas = data.tables |> Obj.keys |> map (.split \. .1) |> unique
            # {'table': ['columns']}
            tables-hash = data.tables 
                |> obj-to-pairs 
                |> concat-map ([k, v]) -> 
                    k = k.to-lower-case!
                    [[k, v], [(k.split \. .1), v]]
                |> pairs-to-obj
            all-tables = tables |> map (-> name: it.to-lower-case!)

            ast = null
            ast-tables = null


            result.on-query-changed: (query) ->
                query = query
                    .replace  /\s+top\s+\d+\s+/gi, ' '
                    .replace /\s+with\s?\(\s?nolock\s?\)\s+/gi, ' '

                err, ast <~ sqlite-parser query
                console.log \parse, err, ast, query
                if !err and !!ast
                    ast = ast.statement
                    # [{name, alias}]
                    ast-tables = ast |> concat-map tables-from-ast 
                    console.log \ast-tables, ast-tables

            
            result.get-completions: (editor, , , prefix, callback) ->
                range = editor.getSelectionRange!.clone!
                    ..set-start range.start.row, 0
                text = editor.session.get-text-range range
                if editor.container.id == \query-editor
                    #console.log \component-did-update, \query-editor, text

                    auto-complete = [keywords: keywords, score: 1] ++ [keywords: alphabet, score: 0]

                    # SQL \/
                    # token is either the last word after space or last word after .
                    token = ((text.split " ")?[*-(if text.ends-with \. then 1 else 2)] ? "").to-lower-case!
                    console.info \token, token
                    if token in <[from join]> ++ schemas
                        # tables
                        auto-complete := [keywords: tables, score: 2] ++ auto-complete
                    else
                        #columns

                        # if token is a table name or alias
                        clean-token = token.split \. .0
                        matching-tables = ast-tables ? [] |> filter ({name, alias}) -> name == clean-token or alias == clean-token

                        # else all the table
                        auto-complete = auto-complete ++ do -> 
                            if matching-tables.length == 0
                                [[(ast-tables ? []), 80], [all-tables, 40]] |> concat-map ([t, s]) -> {keywords: (t |> concat-map (-> tables-hash[it.name])), score: s}
                            else
                                [keywords: (matching-tables |> concat-map (-> tables-hash[it.name])), score: 100]
                    # SQL /\

                    console.log \auto-complete, (convert-to-ace-keywords auto-complete, data-source-cue.type, prefix)
                    callback null, (convert-to-ace-keywords auto-complete, 'server', prefix)    
            
            #TODO: move back to QueryRoute
            if data-source-cue `is-equal-to-object` @state.data-source-cue
                ace-language-tools.set-completers [completer.protocol] ++ (@default-completers |> map (.protocol)) 



        result # not ready-yet result


}

# AST -> [{name, alias}]
tables-from-ast = (ast) ->
    {type, variant} = ast
    
    switch
    |  type == 'identifier' and variant == 'table' =>
        [{name: ast.name, alias: ast.alias}]
    |  type == 'map' and variant == 'join'  =>
        (tables-from-ast ast.source) ++ if !ast.map then [] else ast.map |> concat-map tables-from-ast
    | type == 'statement' and variant == 'select' =>
        (if !ast.from.length then [ast.from] else ast.from) |> concat-map tables-from-ast
    | type == 'join' =>
        [{name: ast.source.name, alias: ast.source.alias}] ++ if !ast.source?.from then [] else tables-from-ast ast.source.from
    | _ => throw "not supported type: #{type}, variant: #{variant} #{JSON.stringify ast, null, 4}"

