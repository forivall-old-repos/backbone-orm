_ = require 'underscore'
rollkuchen = require 'rollkuchen'
option_sets = require '../option_sets'
option_sets_text = null
optionSetsText = ->
  # option_sets_text or= JSON.stringify(option_sets)
  # quick and dirty formatting
  option_sets_text or= JSON.stringify(option_sets).replace('[', '[\n  ').replace(']', '\n]').replace(/\},\{/g, '},\n  {').replace(/:/g, ': ').replace(/,"/g, ', "').replace(/"/g, "'")

indent = (s, n) ->
  indent = (new Array(0|(n+1))).join('  ')
  return s.split('\n').join("\n#{indent}")

module.exports = (source) ->
  target_node = null
  _nodes = []
  result = rollkuchen source, {}, (node) ->
    if node.type is 'AssignOp' and node.assignee?.data in ['option_sets']
      target_node = node
  target_node.expression.update indent(optionSetsText(), (target_node.column - 1) / 2)
  return result.toString()

module.exports.stream = ->
  through = require('through2')
  gutil = require('gulp-util')
  return through.obj (file, enc, cb) ->
    if file.isNull() then (@push(file); return cb())
    if file.isStream() then (this.emit('error', new gutil.PluginError('gulp-traceur', 'Streaming not supported')); return cb())
    file.contents = new Buffer(module.exports(file.contents.toString()))
    @push(file)
    cb()

if require.main is module
  input = ''
  process.stdin.on 'data', (data) -> input += data
  process.stdin.on 'end', ->
    out = module.exports(input)
    process.stdout.write "#{out}\n"
  process.stdin.setEncoding 'utf8'
  process.stdin.resume()

