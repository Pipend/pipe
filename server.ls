body-parser = require \body-parser
{http-port} = require \./config
express = require \express
{MongoClient:{connect}} = require \mongodb
{map} = require \prelude-ls

app = express!
    ..set \views, __dirname + \/
    ..engine \.html, (require \ejs).__express
    ..set 'view engine', \ejs    
    ..use (require \cookie-parser)!
    ..use body-parser.json!
    ..use "/public" express.static "#__dirname/public/"
    ..use "/node_modules" express.static "#__dirname/node_modules/"

app.get \/, (req, res) -> res.render \public/index.html

app.listen http-port
console.log "listening for connections on port: #{http-port}"