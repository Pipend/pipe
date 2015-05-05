browserify = require \browserify
{browserify-debug-mode, gulp-io-port}? = require \./config
gulp = require \gulp
gulp-browserify = require \gulp-browserify 
gulp-livescript = require \gulp-livescript
gulp-rename = require \gulp-rename
gulp-util = require \gulp-util
nodemon = require \gulp-nodemon
run-sequence = require \run-sequence
streamify = require \gulp-streamify
stylus = require \gulp-stylus
uglify = require \gulp-uglify
nib = require \nib
{obj-to-pairs, filter, fold, map, group-by, Obj, sort-by, take, head} = require \prelude-ls
if !!gulp-io-port
    io = (require \socket.io)!
        ..listen gulp-io-port
source = require \vinyl-source-stream
watchify = require \watchify

gulp.task \build:styles, ->
    gulp.src <[./public/components/*.styl]>
    .pipe stylus {use: nib!, compress: true}
    .pipe gulp.dest './public/components'
    .on \end, -> io.emit \build-complete if !!io

gulp.task \watch:styles, ->
    gulp.watch <[./public/components/*.styl]>, <[build:styles]>

create-bundler = (entries) ->
    bundler = browserify {} <<< watchify.args <<< {debug: true}
        ..add entries
        ..transform \liveify
    watchify bundler    

bundle = (bundler, {file, directory}:output) ->
    bundler.bundle!
        .on \error, -> gulp-util.log arguments
        .pipe source file
        .pipe gulp.dest directory

component-bundler = create-bundler \./public/components/App.ls
bundle-components = -> bundle component-bundler, {file: "App.js", directory: "./public/components"}

gulp.task \build:scripts, ->
    bundle-components!

gulp.task \watch:scripts, ->
    component-bundler.on \update, -> 
        io.emit \build-start if !!io
        bundle-components!
    component-bundler.on \time, (time) -> 
        io.emit \build-complete if !!io
        gulp-util.log "App.js built in #{time / 1000} seconds"

gulp.task \dev:server, ->
    nodemon {        
        exec-map: ls: \lsc
        ext: \ls
        ignore: <[gulpfile.ls README.md *.sublime-project public/*]>
        script: \./server.ls
    }

gulp.task \build, <[build:styles build:scripts]>
gulp.task \watch, <[watch:styles watch:scripts]>
gulp.task \default, -> run-sequence \build, <[watch dev:server]>
