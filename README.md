# Pipe

Pipe is a Web app for querying any data source, and analyzing and visualizing the result.

# Query |> Transform |> Visualize

You can query various kind of databases, pipe the result of the query to your alaysis code and pipe the transformed result to visualiaze the result.

# Setup
* Start a mongodb instance
* Start a redis instance (optional, it is only necessary if you choose `redis-store` value for `cache-store` config; see below.)
* `$ git clone https://github.com/Pipend/pipe.git`
* `$ sudo npm install`
* Create `config.ls` in the root of the repository with the following content.
* Update `query-database-connection-string` to the query string of your mongodb instance
* Configure `connections` hash by specifying the connection details for the databses that you like to connect and query. Each connection is a LiveScript hash; you can configure as many connections as you like for the following kind  databses: MongoDB, MSSQL, PostgreSQL, MySQL.
* Configure `cache-store` as instructed in the `config.ls`, you can choose either `redis-store` or `js-store` (in-memory)
* `$ gulp`
* Open a browser and navigate to http://localhost:4081

## config.ls
```livescript
server-config = {
    connections:
        mongodb: # is a hash of connection-primes (server-connection, database-connection or ...) 
            local:
                label: \local
                host: \127.0.0.1
                port: 27017            
                allow-disk-use: true
                timeout: 1000*60*10
        mssql: 
            local:
                server: ''
                user: ''
                password: ''
                default-database: ''
        postgresql:
            local:
                host: ''
                port: ''
                user: ''
                password: ''
                default-database: ''
        mysql:
            local:
                host: ''
                user: ''
                password: ''
                default-database: ''
    default-data-source:
        connection-kind: \pre-configured
        query-type: \mongodb
        connection-name: \local
        database: \pipe
        collection: \queries
        complete: true
    # the js-store uses javascript object for caching & does not persist across application restarts
    # cache-store:
    #    type: \js-store
    #    expires-in: 2 * 24 * 60 * 60 # = 2 days
    cache-store:
        type: \redis-store
        host: \localhost
        port: 6379
        database: 10
        expires-in: 2 * 24 * 60 * 60 # = 2 days
    http-port: 4081
    mongo-connection-opitons:
        auto_reconnect: true
        db:
            w:1
        server:
            socket-options:
                keep-alive: 1
    query-database-connection-string: \mongodb://localhost:27017/pipe
    gulp:
        minify: true        
}

local-config = {} <<< server-config <<< {
    gulp:
        minify: false
        reload-port: 4082
}

module.exports = local-config
```

For the screenshot feature make sure you have PhantomJS ≥ 2.0.1 in your PATH.
