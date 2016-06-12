CompleteDataSourceCue = (require \../../components/CompleteDataSourceCue.ls) <[server user password database]>
PartialDataSourceCue = require \./PartialDataSourceCue.ls
{make-auto-completer} = require \../auto-complete-utils.ls
{concat-map, map, filter, Obj, obj-to-pairs, pairs-to-obj, unique} = require \prelude-ls
editor-settings = require \../default-editor-settings.ls

# tables-from-query :: String -> [{name :: String, alias :: String?}]
tables-from-query = (query) ->
    query
    .replace /--.*$/gmi, ''
    .replace /(WITH\s?)?\(NOLOCK\)/gmi, ''
    .split /[ , \r\n \n]+/
    .reduce do
        # expect :: Enum | {what :: Enum, table :: String, alias :: String? }
        # tables :: [{name :: String, alias :: String?}]
        ({expect, tables}:acc, token) ->
            ctoken = token.to-lower-case!
            switch
            | 'Any' == expect =>
                if ctoken in <[from join]>
                    {expect: 'Table', tables}
                else
                    {expect: 'Any', tables}
            | 'Table' == expect =>
                {expect: {what: 'As', table: token}, tables}
            | expect.what == 'As' => 
                switch
                | ctoken == 'as' =>
                    {expect: {what: 'Alias', table: expect.table}, tables}
                | ctoken in <[inner join outer on where]> =>
                    {expect: 'Any', tables: tables ++ [{table: expect.table, alias: null}]}
                | _ =>
                    {expect: {what: 'AliasWithoutTableName', table: expect.table, alias: token}, tables}
            | expect.what == 'Alias' =>
                {expect: 'Any', tables: tables ++ [{table: expect.table, alias: token}]}
            | expect.what == 'AliasWithoutTableName' =>
                switch
                | ctoken in <[inner join outer on where]> =>
                    {expect: 'Any', tables: tables ++ [{table: expect.table, alias: expect.alias}]}
                | _ =>
                    {expect: 'Any', tables: tables ++ [{table: expect.table, alias: null}]}
            | _ => throw "Unexpected 'expect' #{JSON.stringify expect}"
            
        {expect: 'Any', tables: []}
    .tables |> map ({table, alias}) -> {name: table, alias}    

module.exports =

    # data-source-cue-popup-settings :: a -> DataSourceCuePopupSettings
    data-source-cue-popup-settings: ->
        supports-connection-string: true
        partial-data-source-cue-component: PartialDataSourceCue
        complete-data-source-cue-component: CompleteDataSourceCue

    # query-editor-settings :: String -> AceEditorSettings
    query-editor-settings: (_) -> 
        {} <<< editor-settings! <<< ace-editor-props:
            mode: \ace/mode/sql
            theme: \ace/theme/monokai

    # transformation-editor-settings :: String -> AceEditorSettings
    transformation-editor-settings: editor-settings

    # presentation-editor-settings :: String -> AceEditorSettings
    presentation-editor-settings: editor-settings

    # make-auto-completer :: (AceEditor -> Boolean) -> [DataSourceCue, String] -> p (String -> p AST)
    make-auto-completer: (filter-function, source-and-language) ->
        
        make-auto-completer do
            filter-function
            source-and-language

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
                token = ((text.split /[\s+\(]/)?[*-(if text.ends-with \. then 1 else 2)] ? "").to-lower-case!.replace /[\)\[\]\-\$\^\.\*\\\%\_\+\=\'\"\`\~\?\<\>\{\}\#\@\|]/ig, ''

                if token in <[from join]> ++ schemas
                    # tables
                    auto-complete := [keywords: tables, score: 80] ++ auto-complete
                else
                    #columns

                    # if token is a table name or alias
                    clean-token = token.split \. .0

                    reg-clean-token = new RegExp "^#{clean-token}$", "i"

                    matching-tables = ast-tables ? [] |> filter ({name, alias}) -> reg-clean-token.test name or reg-clean-token.test alias

                    # + all other tables (with lower score)
                    auto-complete = auto-complete ++ do -> 
                        if matching-tables.length == 0
                            ast-tables ? [] |> concat-map (t) -> {keywords: (unique <| t |> concat-map (-> tables-hash[it.name.to-lower-case!])), score: 80}
                        else
                            [keywords: (unique <| matching-tables |> concat-map (-> tables-hash[it.name.to-lower-case!])), score: 100]
                

                Promise.resolve auto-complete