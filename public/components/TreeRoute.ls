{filter, map} = require \prelude-ls
{DOM:{div}}:React = require \react
$ = require \jquery-browserify
CommitTree = require \./CommitTree.ls

module.exports = React.create-class {

    display-name: \DiffRoute

    render: ->
        div {class-name: \tree-route},
            React.create-element do 
                CommitTree
                width: window.inner-width
                height: window.inner-height
                queries: @.state.queries
                tooltip-keys: 
                    * key: \queryId
                      name: 'Query Id'
                    * key: \branchId
                      name: 'Branch Id'
                    * key: \queryTitle
                      name: \Title
                    * key: \creationTime
                      name: \Date

    component-did-mount: -> 
        queries <~ $.getJSON "/apis/queries/#{@.props.params.query-id}/tree"
        @.set-state {queries}

    get-initial-state: ->
        queries: []

}