require! \browserify
require! \./config
require! \gulp
require! \gulp-browserify 
require! \gulp-if
require! \gulp-livescript
require! \gulp-rename
require! \gulp-util
require! \gulp-nodemon
require! \run-sequence
require! \gulp-streamify
require! \gulp-stylus
require! \gulp-uglify
require! \nib
{each, map} = require \prelude-ls
{once} = require \underscore
source = require \vinyl-source-stream
watchify = require \watchify

# only required for livereload & hence initialized in dev:server task
# initializing and listening for connections here breaks tavis-ci
io = null

# emit-with-delay :: String -> IO()
emit-with-delay = (event) ->
    if !!io
        set-timeout do 
            -> io.emit event
            200

# STYLES
gulp.task \build:styles, ->
    gulp.src <[./public/*.styl]>
    .pipe gulp-stylus {use: nib!, import: <[nib]>, compress: config.gulp.minify, "include css": true}
    .pipe gulp.dest './public'
    .on \end, -> emit-with-delay \build-complete if io

gulp.task \watch:styles, ->
    gulp.watch <[./public/components/*.styl ./public/*.styl]>, <[build:styles]>

# create-bundler :: [String] -> Bundler
create-bundler = (entries) ->
    bundler = browserify {} <<< watchify.args <<< debug: !config.gulp.minify
        ..add entries
        ..transform \liveify

# bundler :: Bundler -> {file :: String, directory :: String} -> IO()
bundle = (bundler, {file, directory}:output) ->
    bundler.bundle!
        .on \error, -> gulp-util.log arguments
        .pipe source file
        .pipe gulp-if config.gulp.minify, (gulp-streamify gulp-uglify!)
        .pipe gulp.dest directory

# build-and-watch :: Bundler -> {file :: String, directory :: String} -> (() -> Void) -> (() -> Void) -> (() -> Void)
build-and-watch = (bundler, {file}:output, done, on-update, on-build) ->
    # must invoke done only once
    once-done = once done

    watchified-bundler = watchify bundler

    # build once
    bundle watchified-bundler, output

    watchified-bundler
        .on \update, -> 
            if on-update
                on-update!
            bundle watchified-bundler, output
        
        .on \time, (time) ->
            if on-build
                on-build!
            once-done!
            gulp-util.log "#{file} built in #{time / 1000} seconds"

# SCRIPTS
files = 
    *   name: \index
        on-update: -> emit-with-delay \build-start
        on-build: -> emit-with-delay \build-complete

    *   name: \login

    *   name: \presentation

files |> each ({name, on-update, on-build}?) ->
    ls = create-bundler "./public/#{name}.ls"
    js = directory: \./public, file: "#{name}.js"
    
    gulp.task "build:#{name}:scripts", ->
        bundle ls, js

    gulp.task "build-and-watch:#{name}:scripts", (done) ->
        build-and-watch ls, js, done, on-update, on-build

# SERVER
gulp.task \dev:server, ->
    if !!config?.gulp?.reload-port
        io := (require \socket.io)!
            ..listen config.gulp.reload-port

    gulp-nodemon do
        ext: \ls
        exec-map: 
            ls: \lsc
        ignore: <[gulpfile.ls README.md *.sublime-project public/* node_modules/* migrations/* test/*]>
        script: \./server.ls

# ENTRY POINT
gulp.task \build, <[build:styles build:index:scripts build:presentation:scripts]>
gulp.task \default, -> run-sequence do 
    <[build:styles]>
    <[
        build-and-watch:index:scripts
        build-and-watch:login:scripts
        build-and-watch:presentation:scripts
        watch:styles 
    ]>
    <[dev:server]>
