trap 'kill %1; kill %2' SIGINT
redis-server /usr/local/etc/redis.conf & 
mongod --config /usr/local/etc/mongod.conf &
./node_modules/.bin/gulp
