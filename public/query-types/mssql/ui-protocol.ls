CompleteDataSourceCue = (require \../../components/CompleteDataSourceCue.ls) <[server user password database]>
PartialDataSourceCue = require \./PartialDataSourceCue.ls
{make-auto-completer} = require \../auto-complete-utils.ls

{concat-map, map, filter, Obj, obj-to-pairs, pairs-to-obj, unique} = require \prelude-ls


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

                resolve tables-from-query query

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

# String -> [{name, alias}]
tables-from-query = (query) ->
    query
    .replace /--.*$/gmi, ''
    .replace /(WITH\s?)?\(NOLOCK\)/gmi, ''
    .split /[ , \r\n \n]+/
    .reduce do
        ({expect, tables}:acc, token) ->
            ltoken = token.to-lower-case!
            switch
            | 'Any' == expect =>
                if ltoken in <[from join]>
                    {expect: 'Table', tables}
                else
                    {expect: 'Any', tables}
            | 'Table' == expect =>
                {expect: {what: 'As', table: token}, tables}
            | expect.what == 'As' => 
                switch
                | ltoken == 'as' =>
                    {expect: {what: 'Alias', table: expect.table}, tables}
                | ltoken in <[inner join outer on]> =>
                    {expect: 'Any', tables: tables ++ [{table: expect.table, alias: null}]}
                | _ =>
                    {expect: {what: 'AliasWithoutTableName', table: expect.table, alias: token}, tables}
            | expect.what == 'Alias' =>
                {expect: 'Any', tables: tables ++ [{table: expect.table, alias: token}]}
            | expect.what == 'AliasWithoutTableName' =>
                switch
                | ltoken in <[inner join outer on]> =>
                    {expect: 'Any', tables: tables ++ [{table: expect.table, alias: expect.alias}]}
                | _ =>
                    {expect: 'Any', tables: tables ++ [{table: expect.table, alias: null}]}
            | _ => throw "Unexpected expect #{JSON.stringify expect}"
            
        {expect: 'Any', tables: []}
    .tables |> map ({table, alias}) -> {name: table, alias}    