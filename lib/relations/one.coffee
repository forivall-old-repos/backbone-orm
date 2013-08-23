util = require 'util'
_ = require 'underscore'
Backbone = require 'backbone'
inflection = require 'inflection'
Queue = require 'queue-async'

Utils = require '../utils'
bbCallback = Utils

# @private
module.exports = class One extends require('./relation')
  constructor: (@model_type, @key, options) ->
    @[key] = value for key, value of options
    @ids_accessor or= "#{@key}_id"
    @join_key = inflection.foreign_key(@model_type.model_name) unless @join_key
    @foreign_key = inflection.foreign_key(if @type is 'belongsTo' then @key else (@as or @model_type.model_name)) unless @foreign_key

  initialize: ->
    @reverse_relation = @_findOrGenerateReverseRelation(@)
    throw new Error "Both relationship directions cannot embed (#{@model_type.model_name} and #{@reverse_model_type.model_name}). Choose one or the other." if @embed and @reverse_relation and @reverse_relation.embed

  initializeModel: (model) ->
    model.setLoaded(@key, !!(@embed or @reverse_relation?.embed))
    @_bindBacklinks(model)

  releaseModel: (model) ->
    @_unbindBacklinks(model)
    delete model._orm

  set: (model, key, value, options) ->
    throw new Error "One.set: Unexpected key #{key}. Expecting: #{@key} or #{@ids_accessor}" unless (key is @key or key is @ids_accessor)
    throw new Error "One.set: cannot set an array for attribute #{@key} on #{@model_type.model_name}" if _.isArray(value)
    value = null if _.isUndefined(value) # Backbone clear or reset

    return @ if value is (previous_related_model = model.get(@key)) # no change
    is_model = (value instanceof Backbone.Model)
    Utils.orSet(model, 'rel_dirty', {})[@key] = true
    model.setLoaded(@key, true) if not model.isLoaded(@key) and (is_model or _.isObject(value)) # set loaded state

    # set the relation now or later merge into the existing model
    if value and not is_model
      value = Utils.updateOrNew(value, @reverse_model_type) unless merge_into_existing = Utils.dataId(previous_related_model) is Utils.dataId(value)
    Backbone.Model::set.call(model, @key, value, options) unless merge_into_existing

    # not setting a new model, update the previous model
    if merge_into_existing
      Utils.updateModel(previous_related_model, value)

    # update in memory - clear the reverse relation if it's loaded
    else if (value is null) and @reverse_relation and (@reverse_relation.type is 'hasOne' or @reverse_relation.type is 'belongsTo')
      unless (@embed or @reverse_relation.embed)
        previous_related_model.set(@reverse_relation.key, null) if model.isLoaded(@key) and previous_related_model and (previous_related_model.get(@reverse_relation.key) is model)

    return @

  get: (model, key, callback) ->
    throw new Error "One::get: Unexpected key #{key}. Expecting: #{@key} or #{@ids_accessor}" unless (key is @key or key is @ids_accessor)

    returnValue = =>
      return null unless related_model = model.attributes[@key]
      return if key is @ids_accessor then related_model.id else related_model

    # asynchronous path, needs load
    if callback and not @isVirtual() and not @manual_fetch and not (is_loaded = model.isLoaded(@key) or not model.id) # already loaded or not loadable)
      @cursor(model, key).toJSON (err, json) =>
        return callback(err) if err
        model.setLoaded(@key, true)

        model.set(@key, related_model = if json then Utils.updateOrNew(json, @reverse_model_type) else null)
        callback(null, returnValue())

    # synchronous path
    result = returnValue()
    callback(null, result) if callback and (is_loaded or @manual_fetch)
    return result

  save: (model, callback) ->
    return callback() if not @_hasChanged(model)
    delete Utils.orSet(model, 'rel_dirty', {})[@key]
    return callback() unless related_model = model.attributes[@key]
    @_saveRelated(model, [related_model], callback)

  destroyOne: (model, related, callback) ->
    related_id = Utils.dataId(related)
    if current_related_model = model.get(@key)
      model.set(@key, null) if current_related_model.id is related_id

    # clear in store on us
    if @type is 'belongsTo'
      model.save {}, bbCallback callback

    # clear in store on related
    @cursor(model, @key).toJSON (err, related_json) =>
      return callback(err) if err
      return callback() unless related_json
      @_clearAndSaveRelatedBacklink(model, related_json, callback)

  destroyAll: (model, callback) ->
    return callback() if not @reverse_relation
    delete Utils.orSet(model, 'rel_dirty', {})[@key] if model instanceof Backbone.Model

    @cursor(model, @key).toJSON (err, related_json) =>
      return callback(err) if err
      return callback() unless related_json
      @_clearAndSaveRelatedBacklink(model, related_json, callback)

  appendJSON: (json, model, key) ->
    return if key is @ids_accessor # only write the relationships
    return if @isVirtual() # skip virtual attributes

    json_key = if @embed then key else @ids_accessor
    unless related_model = model.attributes[key]
      json[json_key] = null if @embed or @type is 'belongsTo'
      return
    return json[json_key] = related_model.toJSON() if @embed
    return json[json_key] = related_model.id if @type is 'belongsTo'

  cursor: (model, key, query) ->
    query = _.extend({$one:true}, query or {})
    # return VirtualCursor(query, {model: model, relation: @}) if @manual_fetch # TODO: need to write tests and generalize the checks isFetchable
    if model instanceof Backbone.Model
      if @type is 'belongsTo'
        if related_model = related_model = model.attributes[@key]
          query.id = related_model.id
      else
        query[@foreign_key] = model.id
    else
      # json
      if @type is 'belongsTo'
        query.id = model[@foreign_key]
      else
        query[@foreign_key] = model.id

    query.$values = ['id'] if key is @ids_accessor
    return @reverse_model_type.cursor(query)

  ####################################
  # Internal
  ####################################
  _bindBacklinks: (model) ->
    return unless @reverse_relation
    events = Utils.set(model, 'events', {})

    setBacklink = (related_model) =>
      if @reverse_relation.add
        @reverse_relation.add(related_model, model)
      else
        related_model.set(@reverse_relation.key, model)

    events.change = (model) =>
      related_model = model.get(@key)
      previous_related_model = model.previous(@key)
      return if Utils.dataId(related_model) is Utils.dataId(previous_related_model) # no change

      # update backlinks
      if previous_related_model and (@reverse_relation and @reverse_relation.type isnt 'belongsTo') # allow for multiple
        if @reverse_relation.remove
          @reverse_relation.remove(previous_related_model, model) if not @isVirtual() or not related_model
        else
          current_model = previous_related_model.get(@reverse_relation.key)
          previous_related_model.set(@reverse_relation.key, null) if Utils.dataId(current_model) is model.id

      setBacklink(related_model) if related_model

    # TODO: how to unbind
    model.on("change:#{@key}", events.change) # bind

    # already set, set up initial value
    setBacklink(related_model) if related_model = model.get(@key)

    return model

  _unbindBacklinks: (model) ->
    return unless events = Utils.get(model, 'events') # already unbound
    Utils.unset(model, 'events')

    model.attributes[@key] = null
    model.off("change:#{@key}", events.change) # unbind
    events.change = null
    return

  _hasChanged: (model) ->
    return !!Utils.orSet(model, 'rel_dirty', {})[@key] or model.hasChanged(@key)
    return false unless @reverse_relation
    return false unless related_model = model.attributes[@key]
    return related_model.hasChanged(@reverse_relation.foreign_key)
