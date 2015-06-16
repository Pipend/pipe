#Setup
* sudo npm install
* copy the following to ```config.ls``` :
```
server-config = {
    connections:
        mongodb: # is a hash of connection-primes (server-connection, database-connection or ...) 
            local:
                host: \127.0.0.1
                port: 27017            
    default-data-source:
        type: \mongodb
        connection-name: \local
        database: \pipe
        collection: \queries
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