{camelize, each} = require \prelude-ls
{test-public-readable, test-authenticated-user-in-role} = (require \../test-utils)!

describe \documents, ->
    
    public-readable-actions = 
        *   action-name: \get-document-version 
            parameters: [\document1, 1]
            
        *   action-name: \get-latest-document
            parameters: [\document1]
            
        *   action-name: \get-document-history
            parameters: [\document1]
            
        *   action-name: \get-documents-in-a-project
            parameters: []
        ...

    member-only-actions = 
        *   action-name: \save-document
            parameters: [{query: 'query', transformation: 'transformation'}]
            
        *   action-name: \delete-document-version
            parameters: [\document1, 1]
            
        *   action-name: \delete-document-and-history
            parameters: [\document1]
        ...

    public-readable-actions |> each ({action-name, parameters}) ->
        describe action-name, ->
            test-public-readable do 
                camelize action-name
                parameters
            
    member-only-actions |> each ({roles, action-name, parameters}) ->
        describe action-name, ->
            test-authenticated-user-in-role do 
                <[owner admin collaborator]>
                camelize action-name
                parameters