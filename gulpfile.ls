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
{obj-to-pairs, filter, fold, map, group-by, Obj, sort-by, take, head} = require \prelude-ls
{once} = require \underscore
source = require \vinyl-source-stream
watchify = require \watchify
io = null

# emit-with-delay :: String -> IO()
emit-with-delay = (event) ->
    if !!io
        set-timeout do 
            -> io.emit event
            200

# COMPONENTS STYLES
gulp.task \build:components:styles, ->
    gulp.src <[./public/components/*.styl]>
    .pipe gulp-stylus {use: nib!, import: <[nib]>, compress: config.gulp.minify, "include css": true}
    .pipe gulp.dest './public/components'
    .on \end, -> emit-with-delay \build-complete if !!io

gulp.task \watch:components:styles, ->
    gulp.watch <[./public/components/*.styl]>, <[build:components:styles]>

# PRESENTATION STYLES
gulp.task \build:presentation:styles, ->
    gulp.src <[./public/presentation/*.styl]>
    .pipe gulp-stylus {use: nib!, import: <[nib]>, compress: config.gulp.minify, "include css": true}
    .pipe gulp.dest './public/presentation'

gulp.task \watch:presentation:styles, ->
    gulp.watch <[./public/presentation/*.styl]>, <[build:presentation:styles]>

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
            if !!on-update
                on-update!
            bundle watchified-bundler, app-js
        .on \time, (time) ->
            if !!on-build
                on-build!
            once-done!
            gulp-util.log "#{file} built in #{time / 1000} seconds"

# COMPONENTS SCRIPTS
components-bundler = create-bundler \./public/components/App.ls
app-js = directory: "./public/components", file: "App.js"

gulp.task \build:components:scripts, ->
    bundle components-bundler, app-js

gulp.task \build-and-watch:components:scripts, (done) ->
    build-and-watch do 
        components-bundler
        app-js
        done
        -> emit-with-delay \build-start
        -> emit-with-delay \build-complete

# PRESENTATION SCRIPTS
presentation-bundler = create-bundler \./public/presentation/presentation.ls
presentation-js = file: "presentation.js", directory: "./public/presentation"

gulp.task \build:presentation:scripts, ->
    bundle presentation-bundler, presentation-js

gulp.task \build-and-watch:presentation:scripts, (done) ->
    build-and-watch presentation-bundler, presentation-js, done

gulp.task \dev:server, ->
    if !!config?.gulp?.reload-port
        io := (require \socket.io)!
            ..listen config.gulp.reload-port

    gulp-nodemon do
        exec-map: ls: \lsc
        ext: \ls
        ignore: <[gulpfile.ls README.md *.sublime-project public/* node_modules/* migrations/*]>
        script: \./server.ls

gulp.task \build, <[build:components:styles build:components:scripts build:presentation:styles build:presentation:scripts]>
gulp.task \default, -> run-sequence do 
    <[build:components:styles build:presentation:styles]>
    <[
        build-and-watch:components:scripts 
        build-and-watch:presentation:scripts 
        watch:components:styles 
        watch:presentation:styles
    ]>
    <[dev:server]>
