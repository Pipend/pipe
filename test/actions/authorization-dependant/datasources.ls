Promise = require \bluebird
require! \assert
{is-equal-to-object} = require \prelude-extension
{test-authorization-dependant-action, test-authenticated-user-in-role} = (require \../test-utils)!

describe \datasources, ->
    
    describe \get-connections, ->
        test-authenticated-user-in-role do 
            <[owner admin collaborator]>
            \getConnections
            [\mongodb, {}]
            (result) ->
                expected-result = 
                    connections: 
                        *   label: 'local' 
                            value: 'local'
                        *   label: \secret
                            value: \secret
                        ...
                assert result `is-equal-to-object` expected-result

    describe \extract-data-source, ->

        specify 'must extract data-source for connection-name local', ->
            test-authorization-dependant-action do
                \collaborator
                \private
                \extractDataSource
                [{
                    query-type: \mongodb
                    connection-kind: \pre-configured
                    connection-name: \local
                    database: \test
                    collection: \events
                }]
                true
                (data-source) ->
                    expected-result =
                        queryType: \mongodb
                        connectionName: \local
                        database: \test
                        collection: \events
                        host: \127.0.0.1
                        port: 27017 
                        permission: \publicExecutable
                    assert expected-result `is-equal-to-object` data-source

        specify 'must fail to extract data-source for connection-name unknown', ->
            test-authorization-dependant-action do
                \collaborator
                \private
                \extractDataSource
                [{
                    query-type: \mongodb
                    connection-kind: \pre-configured
                    connection-name: \unknown
                }]
                false