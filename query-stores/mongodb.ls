{bind-p, from-error-value-callback, new-promise, return-p, to-callback} = require \../async-ls
{MongoClient} = require \mongodb
{difference, filter, find-index, map, sort, sort-by, unique} = require \prelude-ls

# :: MongoConfig -> p QueryStore
module.exports = ({connection-string, connection-options}) ->

    res, rej <- new-promise

    err, query-database <- MongoClient.connect connection-string, connection-options

    if !!err
        rej err

    else

        # db-op :: String -> String -> (... -> p result)
        db-op = (function-name, collection-name) ->
            collection = query-database.collection collection-name
            from-error-value-callback collection[function-name], collection

        # aggregate-queries :: [a] -> p result
        aggregate-queries = db-op \aggregate, \queries

        # update-queries :: b -> c -> d -> p result
        update-queries = db-op \update, \queries

        # insert-query :: Document -> p InsertedDocument
        insert-query = db-op \insert, \queries

        res do 

            # delete-branch :: String -> p a
            delete-branch: (branch-id) ->
                results <- bind-p aggregate-queries do
                    * $match: {branch-id}
                    * $project:
                        query-id: 1
                        parent-id: 1
                
                # parent-id of the branch to be deleted
                [parent-id] = difference do
                    results |> map (.parent-id)
                    results |> map (.query-id)

                # set the status of all queries in the branch to false i.e delete 'em all
                <- bind-p update-queries do 
                    {branch-id}
                    {$set: {status: false}}
                    {multi: true}

                # reconnect the children to the parent of the deleted branch
                <- bind-p update-queries do 
                    $and: 
                        * branch-id: $ne: branch-id
                        * parent-id: $in: results |> map (.query-id)
                    {$set: {parent-id}}
                    {multi: true}

                return-p parent-id

            # delete-query :: String -> p a
            delete-query: (query-id) ->
                results <- bind-p aggregate-queries do
                    * $match: {query-id}
                    ...
                
                # update the status property of the query to false
                <- bind-p update-queries do
                    {query-id}
                    {$set: {status: false}}

                # c1 -> c2 -> c3 => c1 -> c3
                <- bind-p update-queries do
                    {parent-id: query-id}
                    {$set: {parent-id: results.0.parent-id}}
                    {multi: true}

                return-p results.0.parent-id

            # get-branches :: String? -> p [{branch-id :: String, latest-query :: Query, snapshot :: String}]
            get-branches: (branch-id) ->
                results <- bind-p aggregate-queries do
                    * $match: {status: true} <<< (if branch-id then {branch-id} else {})
                    * $sort: _id : 1
                    * $group: 
                        _id: \$branchId
                        branch-id: $last: \$branchId
                        query-id: $last: \$queryId
                        query-title: $last: \$queryTitle
                        data-source-cue: $last: \$dataSourceCue
                        presentation: $last: \$presentation
                        tags: $last: \$tags
                        user: $last: \$user
                        creation-time: $last: \$creationTime
                    * $project:
                        _id: 0
                        branch-id: 1
                        query-id: 1
                        query-title: 1
                        data-source-cue: 1
                        tags: 1
                        user: 1
                        creation-time: 1

                return-p do 
                    results
                    |> map ({branch-id}:latest-query) -> 
                        snapshot = "/public/snapshots/#{branch-id}.png"
                        {branch-id, latest-query, snapshot}
                    |> sort-by (.latest-query.creation-time * -1)

            # get-latest-query-in-branch :: String -> p Query
            get-latest-query-in-branch: (branch-id) ->
                results <- bind-p do
                    aggregate-queries do
                        * $match: {branch-id, status: true}
                        * $sort: _id: -1
                if results.length > 0
                    return-p results.0

                else
                    new-promise (, rej) -> rej "unable to find any query in branch: #{branch-id}" 

            # get-queries :: String?, Int, Int -> p [Query]
            get-queries: (branch-id, sort-order = 1, limit = 100) ->
                aggregate-queries do
                    * $match: {branch-id}
                    * $sort: _id: sort-order
                    * $limit: (.limit)

            # get-query-by-id :: String -> p Query
            get-query-by-id: (query-id) ->
                results <- bind-p aggregate-queries do
                    * $match: 
                        query-id: query-id
                        status: true
                    * $sort: _id: - 1
                    * $limit: 1
                
                if results?.0 
                    return-p results.0

                else 
                    new-promise (, rej) -> rej "query not found #{query-id}"

            # Commit :: {parent-id :: String, branch-id :: String, query-title :: String, ...}
            # get-query-version-history :: Stirng -> [Commit]
            get-query-version-history: (query-id) ->

                # get the tree-id from query-id
                queries <- bind-p aggregate-queries do 
                    * $match:
                        query-id: query-id
                        status: true
                    * $project:
                        tree-id: 1

                if queries.length == 0
                    new-promise (, rej) -> rej "unable to find query #{query-id}"

                else
                    aggregate-queries do
                        * $match:
                            tree-id: queries.0.tree-id
                            status: true
                        * $sort: _id: 1
                        * $project:
                            parent-id: 1
                            branch-id: 1
                            query-id: 1
                            query-title: 1
                            creation-time: 1

            # get-tags :: () -> p [String]
            get-tags: ->
                results <- bind-p aggregate-queries do
                    * $match: tags: $exists: true 
                    * $project: tags: 1
                    * $unwind: \$tags
                
                return-p do 
                    results
                    |> map (.tags) >> (.to-lower-case!) >> (.trim!)
                    |> unique
                    |> sort

            # save-query :: Document -> p InsertedDocument
            save-query: ({branch-id, parent-id}:document) ->
                
                # get the latest query in the branch
                results <- bind-p aggregate-queries do
                    * $match:
                        branch-id: branch-id
                        status: true
                    * $project:
                        query-id: 1
                        parent-id: 1
                    * $sort: _id: -1

                if results?.0 and results.0.query-id != parent-id
                    index-of-parent-query = results |> find-index (.query-id == parent-id)

                    queries-in-between = [0 til results.length] 
                        |> map -> [it, results[it].query-id]
                        |> filter ([index])-> index < index-of-parent-query
                        |> map (.1)

                    new-promise (, rej) -> rej {queries-in-between}
                
                else
                    [record]? <- bind-p insert-query do
                        {} <<< document <<< {creation-time: new Date!.get-time!, status: true}
                        {w: 1}
                    return-p record