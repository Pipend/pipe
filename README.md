#Setup
* sudo npm install
* copy the following to ```config.ls``` :
```
server-config = {
    http-port: 4081
    mongo-connection-opitons:
        auto_reconnect: true
        db:
            w:1
        server:
            socket-options:
                keep-alive: 1
    query-database-connection-string: \mongodb://localhost:27017/Mongo-Web-IDE
}

local-config = {} <<< server-config <<< {
    gulp-io-port: 4082
}

module.exports = local-config
```
* run ```gulp```