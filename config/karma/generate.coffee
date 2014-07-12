fs = require 'fs'
path = require 'path'
_ = require 'underscore'
Queue = require 'queue-async'
es = require 'event-stream'

gulp = require 'gulp'
gutil = require 'gulp-util'
shell = require 'gulp-shell'
requireSrc = require 'gulp-require-src'
compile = require 'gulp-compile-js'
concat = require 'gulp-concat'
wrapAMD = require 'gulp-wrap-amd-infer'
webpack = require 'gulp-webpack-config'
browserify = require 'gulp-browserify'

FILES = require '../files'
TEST_GROUPS = require('../test_groups')

module.exports = (callback) ->
  queue = new Queue(1)

  # build webpack
  queue.defer (callback) ->
    gulp.src(['config/builds/test/**/*.webpack.config.coffee', '!config/builds/test/**/*.pre.webpack.config.coffee'], {read: false, buffer: false})
      .pipe(webpack())
      .pipe(es.writeArray (err, array) -> callback(err))

  # # build test browserify
  # for test in TEST_GROUPS.browserify or []
  #   do (test) -> queue.defer (callback) ->
  #     gulp.src(test.build.files)
  #       .pipe(compile({coffee: {bare: true}}))
  #       .pipe(concat(path.basename(test.build.destination)))
  #       .pipe(browserify(test.build.options))
  #       .pipe(gulp.dest(path.dirname(test.build.destination)))
  #       .on('end', callback)

  # # wrap AMD tests
  # for test in TEST_GROUPS.amd or []
  #   do (test) -> queue.defer (callback) ->
  #     gulp.src(test.build.files)
  #       .pipe(compile({coffee: {bare: true, header: false}}))
  #       .pipe(wrapAMD(test.build.options))
  #       .pipe(gulp.dest(test.build.destination))
  #       .on('end', callback)

  queue.await callback