assert = assert or require?('chai').assert

BackboneORM = window?.BackboneORM; try BackboneORM or= require?('backbone-orm') catch; try BackboneORM or= require?('../../../../backbone-orm')
_ = BackboneORM._; Backbone = BackboneORM.Backbone
Queue = BackboneORM.Queue
ModelCache = BackboneORM.CacheSingletons.ModelCache
Utils = BackboneORM.Utils
JSONUtils = BackboneORM.JSONUtils
Fabricator = BackboneORM.Fabricator

option_sets = window?.__test__option_sets or require?('../../../option_sets')
parameters = __test__parameters if __test__parameters?
_.each option_sets, exports = (options) ->
  return if options.embed
  options = _.extend({}, options, parameters) if parameters

  DATABASE_URL = options.database_url or ''
  BASE_SCHEMA = options.schema or {}
  SYNC = options.sync
  BASE_COUNT = 5

  class Flat extends Backbone.Model
    urlRoot: "#{DATABASE_URL}/flats"
    schema: BASE_SCHEMA
    sync: SYNC(Flat)

  describe "Backbone Sync #{options.$parameter_tags or ''}#{options.$tags}", ->

    before (callback) -> ModelCache.configure({enabled: !!options.cache, max: 100}).reset(callback) # configure model cache
    after (callback) ->
      queue = new Queue()
      queue.defer (callback) -> ModelCache.reset(callback)
      queue.defer (callback) -> Utils.resetSchemas [Flat], callback
      queue.await callback

    beforeEach (callback) ->
      queue = new Queue(1)
      queue.defer (callback) -> ModelCache.reset(callback)
      queue.defer (callback) -> Utils.resetSchemas [Flat], callback
      queue.defer (callback) -> Fabricator.create(Flat, BASE_COUNT, {
        name: Fabricator.uniqueId('flat_')
        created_at: Fabricator.date
        updated_at: Fabricator.date
      }, callback)
      queue.await callback

#    it 'saves a model and assigns an id', (done) ->
#      bob = new Flat({name: 'Bob'})
#      assert.equal(bob.get('name'), 'Bob', 'name before save is Bob')
#      assert.ok(!bob.id, 'id before save doesn\'t exist')
#
#      queue = new Queue(1)
#      queue.defer (callback) -> bob.save callback
#
#      queue.defer (callback) ->
#        assert.equal(bob.get('name'), 'Bob', 'name after save is Bob')
#        assert.ok(!!bob.id, 'id after save is assigned')
#        callback()
#
#      queue.await done

    it 'fetches model data', (done) ->
      Flat.findOne (err, model) ->
        assert.ifError(err)
        assert.ok(!!model, 'got model')

        new_model = new Flat({id: model.id})
        new_model.fetch (err) ->
          assert.ifError(err)
          assert.deepEqual(model.toJSON(), new_model.toJSON(), "\nExpected: #{JSONUtils.stringify(model.toJSON())}\nActual: #{JSONUtils.stringify(new_model.toJSON())}")
          done()

#    it 'destroys a model', (done) ->
#      Flat.findOne (err, model) ->
#        assert.ifError(err)
#        assert.ok(!!model, 'got model')
#        model_id = model.id
#
#        model.destroy (err) ->
#          assert.ifError(err)
#
#          Flat.find model_id, (err, model) ->
#            assert.ifError(err)
#            assert.ok(!model, "Model not found after destroy")
#            done()
