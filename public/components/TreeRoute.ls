{filter, map} = require \prelude-ls
{create-factory, DOM:{div}}:React = require \react
$ = require \jquery-browserify
CommitTree = create-factory require \./CommitTree.ls

module.exports = React.create-class do

    display-name: \TreeRoute

    # render :: a -> ReactElement
    render: ->
        div class-name: \tree-route,
            CommitTree do
                width: window.inner-width
                height: window.inner-height
                queries: @state.queries
                tooltip-keys: 
                    * key: \queryId
                      name: 'Query Id'
                    * key: \branchId
                      name: 'Branch Id'
                    * key: \queryTitle
                      name: \Title
                    * key: \creationTime
                      name: \Date

    # component-did-mount :: a -> Void
    component-did-mount: !-> 
        queries <~ $.getJSON "/apis/queries/#{@props.params.query-id}/tree"
        @set-state {queries}

    # get-initial-state :: a -> UIState
    get-initial-state: -> queries: []