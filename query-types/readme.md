# Adding a new Query Type

## 1. Server Side

``` bash
QUERYTYPE=es6promise
touch query-types/$QUERYTYPE
```

``` livescript

# keywords :: (CancellablePromise cp) => [DataSource, String] -> cp [String]
export keywords = ([data-source]) ->
    returnP keywords: <[]>

# get-context :: a -> Context
export get-context = ->
    {} <<< (require \./default-query-context.ls)! <<< (require \prelude-ls)

# for executing a single query POSTed from client
# execute :: (CancellablePromise cp) => TaskManager -> QueryStore -> DataSource -> String -> String -> Parameters -> cp result
export execute = (, , data-source, query, transpilation-language, parameters) -->

    execute = new-promise (resolve, reject) ->
        try
            p = eval(query)
            resolve(p)
        catch ex
            reject ex

    with-cancel-and-dispose do
        execute
        ->
            returnP 'cannot cancel'
        ->
            # cancel

# default-document :: DataSourceCue -> String -> Document
export default-document = (data-source-cue, transpilation-language) ->
    query: """new Promise((resolve, reject) => {
        resolve({hello: 'world!'})
      }) """
    transformation: "id"
    presentation: "json"
    parameters: ""


```

## 2. Client Side
``` bash
mkdir public/query-types/$QUERYTYPE
touch public/query-types/$QUERYTYPE/ui-protocol.ls
```

```
{make-auto-completer-default} = require \../auto-complete-utils.ls
editor-settings = require \../default-editor-settings.ls

module.exports =

    # data-source-cue-popup-settings :: a -> DataSourceCuePopupSettings
    data-source-cue-popup-settings: -> supports-connection-string: false

    # query-editor-settings :: String -> AceEditorSettings
    query-editor-settings: editor-settings

    # transformation-editor-settings :: String -> AceEditorSettings
    transformation-editor-settings: editor-settings

    # presentation-editor-settings :: String -> AceEditorSettings
    presentation-editor-settings: editor-settings

    # make-auto-completer :: (Promise p) => DataSourceCue -> p completions
    make-auto-completer: make-auto-completer-default
```

Edit `public/components/DataSourceCuePopup.ls`
And  `public/components/DocumentRoute.ls`

Add this to ui-protocol:
```
    es6promise: require \../query-types/es6promise/ui-protocol.ls
```
