#Setup
* sudo npm install
* copy the following to ```config.ls``` :
```
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
}

local-config = {} <<< server-config <<< {
    gulp-io-port: 4082
}

module.exports = local-config
```
* run ```gulp```