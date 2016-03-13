require! \assert
{bind-p, return-p} = require \../../../async-ls
require! \../../../exceptions/UnAuthenticatedException
require! \../../../exceptions/UnAuthorizedException
{test-authorization-dependant-action} = (require \../test-utils) do
    get-document-version: (document-id, version) ->
        if document-id == \document1
            return-p do 
                _id: document-id
                version: version
                data-source-cue:
                    query-type: \mongodb
                    connection-kind: \pre-configured
                    connection-name: if version == 2 then \local else \secret
                transpilation:
                    query: \livescript
        
        else
            return-p null

describe \execution, ->

    describe \execute, ->

        document =
            document-id: \document1
            version: 2
            title: \test
            query: '$limit: limit'
            data-source-cue: 
                query-type: \mongodb
                connection-kind: \pre-configured
                connection-name: \local
            transpilation:
                query: \livescript

        run-test = (user-id, project-id, document-override, must-succeed, post-process = (->)) ->
            {document-id, version, data-source-cue, query, transpilation} = {} <<< document <<< document-override
            test-authorization-dependant-action do
                user-id
                project-id
                \execute
                [
                    \prty893
                    url: \test
                    method: \GET
                    user-agent: \TEST
                    document-id
                    version
                    data-source-cue
                    query
                    transpilation.query
                    {limit: 10}
                    true
                ]
                must-succeed
                post-process

        specify 'owner must be allowed to execute any document in a project irrespective of project permission', ->
            run-test \owner, \private, {}, true

        specify 'owner must be allowed to execute modified documents', ->
            run-test do 
                \guest
                \publicExecutable
                data-source-cue:
                    query-type: \unknown
                false

        specify 'guest must be allowed to execute docs with publicExecutable data-source in publicExecutable projects', ->
            <- bind-p (run-test \guest, \publicExecutable, {}, true)
            run-test \guest, \publicReadableAndExecutable, {}, true

        specify 'guest must not be allowed to execute docs in a private project', ->
            run-test \guest, \private, {}, false, (err) ->
                assert err instanceof UnAuthorizedException, err.to-string!

        specify 'guest must not be allowed to execute docs with private data-source even in a public-executable project', ->
            run-test do 
                \guest
                \publicExecutable
                version: 3
                data-source-cue:
                    query-type: \mongodb
                    connection-kind: \pre-configured
                    connection-name: \secret
                false
                (err) ->
                    assert err instanceof UnAuthorizedException, err.to-string!

        specify 'guest must not be allowed to execute a modified document', ->
            run-test do 
                \guest
                \publicExecutable
                data-source-cue:
                    query-type: \unknown
                true

        specify 'guest must not be allowed to execute a non existing document', ->
            run-test do 
                \guest
                \publicExecutable
                document-id: \document2
                false
                (err) ->
                    assert err instanceof UnAuthorizedException, err.to-string!