CompleteDataSourceCue = (require \../../components/CompleteDataSourceCue.ls) <[server user password database]>
PartialDataSourceCue = require \./PartialDataSourceCue.ls

{concat-map, map, filter} = require \prelude-ls
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
        ast = null
        ast-tables = null
        on-query-changed: (query) ->
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
        on-server-keywords = ({keywords}:data) ->
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

