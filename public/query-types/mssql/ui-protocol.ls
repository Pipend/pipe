CompleteDataSourceCue = (require \../../components/CompleteDataSourceCue.ls) <[server user password database]>
PartialDataSourceCue = require \./PartialDataSourceCue.ls
{make-auto-completer} = require \../auto-complete-utils.ls

{concat-map, map, filter, Obj, obj-to-pairs, pairs-to-obj, unique} = require \prelude-ls
sqlite-parser = require \sqlite-parser


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
        
        make-auto-completer do
            data-source-cue

            # on-api-keywords-feteched :: api-keywords -> Promise schema
            ({keywords}:data) -> new Promise (resolve, reject) ->
                
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
                resolve {all-tables, tables, tables-hash, schemas}
            
            # on-query-changed    
            (query, {keywords, schema:{all-tables, tables, tables-hash, schemas}}) -> new Promise (resolve, reject) ->
                
                query := query
                    .replace  /\s+top\s+\d+\s+/gi, ' '
                    .replace /\s+with\s?\(\s?nolock\s?\)\s+/gi, ' '

                err, ast <~ sqlite-parser query

                if !!err
                    reject err
                else if !ast
                    reject Error "Unable to build AST without any error!"
                else
                    ast = ast.statement
                    # [{name, alias}]
                    ast-tables = ast |> concat-map tables-from-ast 

                    resolve ast-tables
            
            # get-completions
            (text, {schema:{all-tables, tables, tables-hash, schemas}, keywords, ast:ast-tables}) ->
                
                auto-complete = []
                token = ((text.split " ")?[*-(if text.ends-with \. then 1 else 2)] ? "").to-lower-case!

                if token in <[from join]> ++ schemas
                    # tables
                    auto-complete := [keywords: tables, score: 80] ++ auto-complete
                else
                    #columns

                    # if token is a table name or alias
                    clean-token = token.split \. .0

                    matching-tables = ast-tables ? [] |> filter ({name, alias}) -> name == clean-token or alias == clean-token


                    # + all other tables (with lower score)
                    auto-complete = auto-complete ++ do -> 
                        if matching-tables.length == 0
                            [[(ast-tables ? []), 80], [all-tables, 40]] |> concat-map ([t, s]) -> {keywords: (t |> concat-map (-> tables-hash[it.name])), score: s}
                        else
                            [keywords: (matching-tables |> concat-map (-> tables-hash[it.name])), score: 100]
                Promise.resolve auto-complete

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

