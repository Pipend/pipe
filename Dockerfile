FROM node:5
MAINTAINER https://github.com/Pipend

# install http-server
RUN npm install -g gulp

RUN mkdir -p /app
WORKDIR /app

# install dependencies
ADD package.json .
RUN npm install -q

# copy source code
ADD . .
ADD config-docker.ls config.ls

# build 
RUN npm run build

EXPOSE 4081

# run
CMD npm start
