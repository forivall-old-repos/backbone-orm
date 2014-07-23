_ = require 'underscore'

# add additional options to test here
OPTION_KEYS = ['cache', 'embed']

arrayToOptions = (keys) ->
  results = {}
  results[key] = (key in keys) for key in OPTION_KEYS
  results.$tags = getTags(results)
  return results

# constructs a string to be used in describe https://github.com/visionmedia/mocha/wiki/Tagging
getTags = (options) ->
  tags = []
  tags.push("@#{if options[option_key] then '' else 'no_'}#{option_key}") for option_key in OPTION_KEYS
  s = tags.join(' ')
  s = "#{s} @no_options" if options.none or not _.any(options)
  return s

module.exports = _.map(require('powerset')(OPTION_KEYS), arrayToOptions)
