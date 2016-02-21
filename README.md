Pipe
=================================

[![Build Status](https://travis-ci.org/Pipend/pipe.svg?branch=master)](https://travis-ci.org/Pipend/pipe)

Pipe is a Web app for querying any data source, and analyzing and visualizing the result.

LIVE DEMO: [http://rf.pipend.com/](http://rf.pipend.com/)

# Deps
* [transpilation](https://github.com/pipend/transpilation)
* [pipe-transformation](https://github.com/pipend/pipe-transformation)
* [pipe-web-client](https://github.com/pipend/pipe-web-client)

# Query |> Transform |> Visualize

You can query various kind of databases, pipe the result of the query to your alaysis code and pipe the transformed result to visualiaze the result.

# Status
The project is currently under development

# Setup
* Start a mongodb instance
* Start a redis instance (optional, it is only necessary if you choose `redis-store` value for `cache-store` config)
* `$ git clone https://github.com/Pipend/pipe.git`
* `$ sudo npm install`
* `npm run configure` to create `config.ls` in the root of the repository. Review and update the following in the config
* Update `query-database-connection-string` to the query string of your mongodb instance
* Configure `connections` hash by specifying the connection details for the databses that you like to connect and query. Each connection is a LiveScript hash; you can configure as many connections as you like for the following kind  databses: MongoDB, MSSQL, PostgreSQL, MySQL.
* Configure `cache-store`, you can choose either `redis-store` or `js-store` (in-memory)
* `$ gulp`
* Open a browser and navigate to http://localhost:4081

For the screenshot feature make sure you have PhantomJS ≥ 2.0.1 in your PATH.
