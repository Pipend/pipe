{bind-p, from-error-value-callback, new-promise, reject-p, return-p, to-callback} = require \../async-ls
require! \base62
{MongoClient, ObjectID} = require \mongodb
{any, difference, filter, find-index, last, map, obj-to-pairs, pairs-to-obj, reject, sort, sort-by, unique} = require \prelude-ls
require! \../exceptions/DocumentSaveException


# TODO: move this to prelude-extension
# reject-keys :: ([String, a] -> Bool) -> Map k, v -> Map k, v
reject-keys = (f, o) -->
    o
    |> obj-to-pairs
    |> reject f
    |> pairs-to-obj

generate-uid = -> base62.encode Date.now!

# :: MongoConfig -> p QueryStore
module.exports = ({connection-string, connection-options}) ->

    res, rej <- new-promise

    err, db <- MongoClient.connect connection-string, connection-options

    if err
        rej err

    else

        # TODO: optimize this method
        # coinverts all props of type ObjectId to String
        # normalize-ids :: p a -> p b
        normalize-ids = (.then JSON.parse . JSON.stringify)

        # object-id :: String -> ObjectID
        object-id = -> new ObjectID it

        # aggregate :: String -> (pipeline -> p result)
        aggregate = (collection-name) ->
            collection = db.collection collection-name
            from-error-value-callback collection.aggregate, collection

        # insert-one-record-and-return-it :: String -> a -> p b
        insert-one-record-and-return-it = (collection-name, object) -->
            {inserted-id} <- bind-p (db.collection collection-name .insert-one object)
            db.collection collection-name .find-one _id: inserted-id


        # --------------- users ---------------

        # insert-user :: User' -> IO(User)
        insert-user = normalize-ids . (insert-one-record-and-return-it \users)

        # get-user-by-email :: String -> p User
        get-user-by-email = (email) ->
            db.collection \users .find-one {email}

        get-user-by-oauth-id = (provider, _id) ->
            db.collection \users .find-one \githubProfile.id : _id


        # --------------- projects ---------------

        # insert-project :: Project' -> IO(Project)
        insert-project = normalize-ids . (insert-one-record-and-return-it \projects)

        # get-project :: String -> p Project
        get-project = (project-id) ->
            normalize-ids do
                db.collection \projects .find-one do
                    _id: object-id project-id
                    status: $ne: false

        # get-projects :: String -> p [Project]
        get-projects = (owner-id) ->
            normalize-ids do
                (aggregate \projects) do
                    * $match:
                        owner-id: owner-id
                        status: $ne: false
                    ...

        # update-project :: String -> object -> IO(Project)
        update-project = (project-id, patch) ->
            if typeof! patch._id == 'String'
                patch._id = object-id patch._id
            db.collection \projects .find-one-and-update do
                {_id: object-id project-id}
                {$set: patch}
            .then (x) ->
                normalize-ids do
                    db.collection \projects .find-one _id: patch._id


        # delete-project :: String -> IO(Project)
        delete-project = (project-id) ->
            update-project project-id, status: false


        # --------------- documents ---------------

        # save-document :: Document ->  -> IO(Document)
        save-document = ({document-id, version}:document, assign-next-available-version-on-conflict = false) ->
            # insert a new document
            if (document-id.index-of \local) == 0
                normalize-ids do
                    insert-one-record-and-return-it do
                        \documents
                        {} <<< document <<<
                            document-id: generate-uid!
                            version: 1
                            creation-time: Date.now!
                            status: true

            else
                result <- bind-p (aggregate \documents) do
                    * $match:
                        document-id: document-id
                        version: $gt: version
                    * $project:
                        version: 1
                        status: 1
                    * $sort: version: 1

                # show a conflict dialog
                if (any (.status == true), result) and !assign-next-available-version-on-conflict
                    reject-p do
                        new DocumentSaveException (result |> filter (.status == true))

                # increment version
                else
                    normalize-ids do
                        insert-one-record-and-return-it do
                            \documents
                            {} <<< document <<<
                                _id: undefined
                                version: 1 + (switch
                                    | result.length == 0 => version
                                    | _ => (last result).version)
                                creation-time: Date.now!
                                status: true

        # get-documents-in-project :: String -> p [{document-id :: String, title :: String, creation-time :: Int}]
        get-documents-in-a-project = (project-id) ->
            (aggregate \documents) do
                * $sort: _id: 1
                * $match:
                    project-id: project-id
                    status: true
                * $group:
                    _id: \$documentId
                    version: $last: \$version
                    title: $last: \$title
                    creation-time: $last: \$creationTime
                * $project:
                    _id: 0
                    document-id: \$_id
                    version: 1
                    title: 1
                    creation-time: 1

        # get-document-version :: String -> Int -> p Document
        get-document-version = (document-id, version) -->
            normalize-ids do
                db.collection \documents .find-one do
                    document-id: document-id
                    version: version
                    status: true

        # get-latest-document :: String -> p Document
        get-latest-document = (document-id) ->
            normalize-ids do
                db.collection \documents .find-one do
                    {document-id, status: true}
                    {sort: version: -1}

        # get-document-history :: String -> p [{_id :: String, version :: Int, title :: String}]
        get-document-history = (document-id) ->
            (aggregate \documents) do
                * $match:
                    document-id: document-id
                    status: true
                * $project:
                    document-id: 1
                    version: 1
                    title: 1
                    creation-time: 1

        # delete-document :: String -> IO()
        delete-document-and-history = (document-id) ->
            db.collection \documents .update do
                {document-id, status: true}
                {$set: status: false}
                {multi: true}

        # delete-document-version :: String -> Int -> IO ()
        delete-document-version = (document-id, version) ->
            db.collection \documents .update do
                {document-id, version, status: true}
                {$set: status: false}

        res {

            insert-user
            get-user-by-email
            get-user-by-oauth-id

            insert-project
            get-project
            get-projects
            update-project
            delete-project

            save-document
            get-documents-in-a-project
            get-document-version
            get-latest-document
            get-document-history
            delete-document-and-history
            delete-document-version

        }
