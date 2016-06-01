require! \path
HtmlWebpackPlugin = require \html-webpack-plugin

module.exports = 
    entry: 
        index: \./public/index.ls
        login: \./public/login.ls
    
    output:

        # this is the path where all the bundled (and/or minified) javascript will be saved by webpack
        # when invoked with -p switch (or when we make any changes to our codebase)
        path: \./public/build
        filename: '[name].js'

        # webpack-dev-server will serve built files at this path 
        # this is the path we will use to reference scripts in index.html file
        public-path: \/

    plugins:
        * new HtmlWebpackPlugin do
            filename: \index.html
            title: 'Pipe'
            template: \public/template.html
            chunks: [\index]

        * new HtmlWebpackPlugin do
            filename: \login.html
            title: 'Login'
            template: \public/template.html
            chunks: [\login]
        ...

    dev-server:
        history-api-fallback: true

        proxy:
            '/apis/*':
                target: \http://localhost:4081

    module:
        loaders:
            * test: /\JSONStream.*index.js$/
              loader: \string-replace
              query:
                search: '#! /usr/bin/env node'
                replace: ''

            * test: /\.ls$/
              loaders: <[react-hot livescript-loader]>

            * test: /\.css$/
              loader: "style-loader!css-loader"

            * test: /\.styl$/
              loader: "style-loader!css-loader!stylus-loader"

            * test: /\.(png|jpg)$/
              loader: "file?name=images/[name].[ext]"
            ...
        no-parse: ["/brace/"]

    stylus:
        use: [(require \nib)!]
        import: ['~nib/lib/nib/index.styl']