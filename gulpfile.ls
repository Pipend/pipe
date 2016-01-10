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
if !!config?.gulp?.reload-port
    io = (require \socket.io)!
        ..listen config.gulp.reload-port
source = require \vinyl-source-stream
watchify = require \watchify

emit-with-delay = (event) ->
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

create-bundler = (entries) ->
    bundler = browserify {} <<< watchify.args <<< {debug: !config.gulp.minify}
        ..add entries
        # ..transform {global: false}, 'browserify-shim'
        ..transform \liveify
    watchify bundler

bundle = (bundler, {file, directory}:output) ->
    bundler.bundle!
        .on \error, -> gulp-util.log arguments
        .pipe source file
        .pipe gulp-if config.gulp.minify, (gulp-streamify gulp-uglify!)
        .pipe gulp.dest directory

# COMPONENTS SCRIPTS
component-bundler = create-bundler \./public/components/App.ls
bundle-components = -> bundle component-bundler, {file: "App.js", directory: "./public/components"}

gulp.task \build:components:scripts, ->
    bundle-components!

gulp.task \watch:components:scripts, ->
    component-bundler.on \update, -> 
        emit-with-delay \build-start if !!io
        bundle-components!
    component-bundler.on \time, (time) -> 
        emit-with-delay \build-complete if !!io
        gulp-util.log "App.js built in #{time / 1000} seconds"

# PRESENTATION SCRIPTS
presentation-bundler = create-bundler \./public/presentation/presentation.ls
bundle-presentation = -> bundle presentation-bundler, {file: "presentation.js", directory: "./public/presentation"}

gulp.task \build:presentation:scripts, ->
    bundle-presentation!

gulp.task \watch:presentation:scripts, ->
    presentation-bundler.on \update, -> bundle-presentation!
    presentation-bundler.on \time, (time) -> gulp-util.log "presentation.js built in #{time / 1000} seconds"

gulp.task \dev:server, ->
    gulp-nodemon do
        exec-map: ls: \lsc
        ext: \ls
        ignore: <[gulpfile.ls README.md *.sublime-project public/* node_modules/* migrations/*]>
        script: \./server.ls

gulp.task \build, <[build:components:styles build:components:scripts build:presentation:styles build:presentation:scripts]>
gulp.task \watch, <[watch:components:styles watch:components:scripts watch:presentation:styles watch:presentation:scripts]>
gulp.task \default, -> run-sequence \build, <[watch dev:server]>
