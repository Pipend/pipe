require! \assert
{bind-p} = require \../../../async-ls
{map} = require \prelude-ls
{is-equal-to-object} = require \prelude-extension

module.exports = (db-p, store-p) ->
    
    describe \documents, ->
        
        describe \save-document, ->
        
            specify "saving a document for the first time must return a new document-id with version 0", ->
                db <- bind-p db-p
                {save-document} <- bind-p store-p
                {document-id, version} <- bind-p save-document do 
                    query: '$limit : 10'
                    document-id: \ps78dyf
                    version: \local
                assert version == 1
                assert document-id != \ps78dyf
                
            specify "saving an existing document must return a new version", ->
                db <- bind-p db-p
                {save-document} <- bind-p store-p
                document1 = 
                    document-id: \1
                    version: 2
                    title: \test
                <- bind-p (db.collection \documents .insert-one document1)
                {document-id, version} <- bind-p save-document document1
                assert version == document1.version + 1
                assert document-id == document1.document-id
            
            specify "saving an existing document must return a new version (case of deleted versions)", ->
                db <- bind-p db-p
                {save-document} <- bind-p store-p
                document1 = 
                    document-id: \1
                    version: 2
                    title: \test
                    status: true
                document2 = {} <<< document1 <<< 
                    version: 1 + document1.version
                    status: false
                <- bind-p (db.collection \documents .insert-many [document1, document2])
                {document-id, version} <- bind-p save-document document1
                assert version == 1 + document2.version
                assert document1.document-id == document-id
                
            specify "saving an older version of a document, when new versions exist, must throw an error", ->
                db <- bind-p db-p
                {save-document} <- bind-p store-p
                document1 = 
                    document-id: \1
                    version: 1
                    status: true
                document2 = {} <<< document1 <<< 
                    version: 1 + document1.version
                <- bind-p (db.collection \documents .insert-many [document1, document2])
                (save-document document1)
                    .then ->
                        throw "expected save-document to throw an error when attempting to save old version of a document"
                    .catch (err) -> 
                        if err.versions-ahead
                            assert err.versions-ahead.length == 1
                            assert err.versions-ahead.0.version == 2
                        else
                            throw err
                        
            specify do 
                """saving an older version of a document with assign-next-available-version-on-conflict true, 
                   must save the document with the next available version"""
                ->
                    db <- bind-p db-p
                    {save-document} <- bind-p store-p
                    document1 = 
                        document-id: \1
                        version: 1
                        status: true
                    document2 = {} <<< document1 <<< 
                        version: 1 + document1.version
                    <- bind-p (db.collection \documents .insert-many [document1, document2])
                    {version} <- bind-p (save-document document1, true)
                    assert version == 1 + document2.version
                        
        describe \get-document-version, ->
                        
            specify "must return the requested version of the document", ->
                db <- bind-p db-p
                {get-document-version} <- bind-p store-p
                expected-document = 
                    document-id: \1
                    version: 1
                    title: \test
                    status: true
                <- bind-p (db.collection \documents .insert-one expected-document)
                {document-id, version, title} <- bind-p (get-document-version \1, 1)
                assert document-id == expected-document.document-id
                assert version == expected-document.version
                assert title == expected-document.title
            
        describe \get-latest-document, ->
            
            specify "must return the latest version of the document", ->
                db <- bind-p db-p
                {get-latest-document} <- bind-p store-p
                document1 = 
                    document-id: \1
                    version: 1
                    title: \test
                    status: true
                document2 = {} <<< document1 <<<
                    version: 1 + document1.version
                    title: \test2
                <- bind-p (db.collection \documents .insert-many [document1, document2])
                {version, title} <- bind-p get-latest-document \1
                assert 2 == version
                assert \test2 == title
                
        describe \get-documents-in-a-project, ->
            
            specify "must return a list of all the documents in the given project", ->
                db <- bind-p db-p
                {get-documents-in-a-project} <- bind-p store-p
                {inserted-id} <- bind-p (db.collection \projects .insert-one title: \test)
                <- bind-p (db.collection \documents .insert-many do 
                    [0 til 10] |> map ->
                        project-id: inserted-id.to-hex-string!
                        document-id: it.to-string!
                        status: it % 2 == 0)
                documents <- bind-p get-documents-in-a-project inserted-id.to-hex-string!
                assert 5 == documents.length
                
        describe \get-document-history, ->
            
            specify "must return a list of all the versions of that document", ->
                db <- bind-p db-p
                {get-document-history} <- bind-p store-p
                dummy-projects = [0 til 10] |> map (version) ->
                    document-id: \1
                    version: version
                    status: true
                <- bind-p (db.collection \documents .insert-many dummy-projects)
                history <- bind-p get-document-history \1    
                assert 10 == history.length
                assert [0 til 10] `is-equal-to-object` (history |> map (.version))
                
        describe \delete-document-and-history, ->
            
            specify "must delete all the versions of a given document", ->
                db <- bind-p db-p
                {delete-document-and-history} <- bind-p store-p
                dummy-projects = [0 til 10] |> map (version) ->
                    document-id: \1
                    version: version
                    status: true
                <- bind-p (db.collection \documents .insert-many dummy-projects)
                <- bind-p delete-document-and-history \1
                document <- bind-p (db.collection \documents .find-one document-id: \1, status: true)
                assert.equal null, document
                
        describe \delete-document-version, ->
                
            specify "must delete the specified version of the given document", ->
                db <- bind-p db-p
                {delete-document-version} <- bind-p store-p
                <- bind-p (db.collection \documents .insert-one do 
                    document-id: \1
                    version: 1
                    title: \test
                    status: true)
                <- bind-p delete-document-version \1, 1
                document <- bind-p (db.collection \documents .find-one document-id: \1, version: 1, status: true)
                assert.equal null, document