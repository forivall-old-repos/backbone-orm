assert = assert or require?('chai').assert

BackboneORM = window?.BackboneORM; try BackboneORM or= require?('backbone-orm') catch; try BackboneORM or= require?('../../../backbone-orm')
{_, Backbone, Queue, Utils, JSONUtils, Fabricator} = BackboneORM

option_sets = window?.__test__option_sets or require?('../../option_sets')
parameters = __test__parameters if __test__parameters?
_.each option_sets, exports = (options) ->
  options = _.extend({}, options, parameters) if parameters

  DATABASE_URL = options.database_url or ''
  BASE_SCHEMA = options.schema or {}
  SYNC = options.sync
  BASE_COUNT = 5

  OMIT_KEYS = ['owner_id', '_rev', 'created_at', 'updated_at']


  describe "hasMany #{options.$parameter_tags or ''}#{options.$tags}", ->
    Flat = Reverse = ForeignReverse = Owner = null

    before ->
      BackboneORM.configure {naming_convention: 'camelize'}

      class Flat extends Backbone.Model
        urlRoot: "#{DATABASE_URL}/flats"
        schema: BASE_SCHEMA
        sync: SYNC(Flat)

      class Reverse extends Backbone.Model
        urlRoot: "#{DATABASE_URL}/reverses"
        schema: _.defaults({
          owner: -> ['belongsTo', Owner]
          anotherOwner: -> ['belongsTo', Owner, as: 'moreReverses']
        }, BASE_SCHEMA)
        sync: SYNC(Reverse)

      class ForeignReverse extends Backbone.Model
        urlRoot: "#{DATABASE_URL}/foreign_reverses"
        schema: _.defaults({
          owner: -> ['belongsTo', Owner, foreign_key: 'ownerish_id']
        }, BASE_SCHEMA)
        sync: SYNC(ForeignReverse)

      class Owner extends Backbone.Model
        urlRoot: "#{DATABASE_URL}/owners"
        schema: _.defaults({
          flats: -> ['hasMany', Flat]
          reverses: -> ['hasMany', Reverse]
          moreReverses: -> ['hasMany', Reverse, as: 'anotherOwner']
          foreignReverses: -> ['hasMany', ForeignReverse]
        }, BASE_SCHEMA)
        sync: SYNC(Owner)

    after (callback) ->
      BackboneORM.configure({naming_conventions: 'default'})

      queue = new Queue()
      queue.defer (callback) -> BackboneORM.model_cache.reset(callback)
      queue.defer (callback) -> Utils.resetSchemas [Flat, Reverse, ForeignReverse, Owner], callback
      queue.await callback
    after -> Flat = Reverse = ForeignReverse = Owner = null

    beforeEach (callback) ->
      relation = Owner.relation('reverses')
      delete relation.virtual
      MODELS = {}

      queue = new Queue(1)
      queue.defer (callback) -> BackboneORM.configure({model_cache: {enabled: !!options.cache, max: 100}}, callback)
      queue.defer (callback) -> Utils.resetSchemas [Flat, Reverse, ForeignReverse, Owner], callback
      queue.defer (callback) ->
        create_queue = new Queue()

        create_queue.defer (callback) -> Fabricator.create(Flat, 2*BASE_COUNT, {
          name: Fabricator.uniqueId('flat_')
          created_at: Fabricator.date
        }, (err, models) -> MODELS.flat = models; callback(err))
        create_queue.defer (callback) -> Fabricator.create(Reverse, 2*BASE_COUNT, {
          name: Fabricator.uniqueId('reverse_')
          created_at: Fabricator.date
        }, (err, models) -> MODELS.reverse = models; callback(err))
        create_queue.defer (callback) -> Fabricator.create(Reverse, 2*BASE_COUNT, {
          name: Fabricator.uniqueId('reverse_')
          created_at: Fabricator.date
        }, (err, models) -> MODELS.more_reverse = models; callback(err))
        create_queue.defer (callback) -> Fabricator.create(ForeignReverse, BASE_COUNT, {
          name: Fabricator.uniqueId('foreign_reverse_')
          created_at: Fabricator.date
        }, (err, models) -> MODELS.foreign_reverse = models; callback(err))
        create_queue.defer (callback) -> Fabricator.create(Owner, BASE_COUNT, {
          name: Fabricator.uniqueId('owner_')
          created_at: Fabricator.date
        }, (err, models) -> MODELS.owner = models; callback(err))

        create_queue.await callback

      # link and save all
      queue.defer (callback) ->
        save_queue = new Queue(1)

        link_tasks = []
        for owner in MODELS.owner
          link_task =
            owner: owner
            values:
              flats: [MODELS.flat.pop(), MODELS.flat.pop()]
              reverses: [MODELS.reverse.pop(), MODELS.reverse.pop()]
              moreReverses: [MODELS.more_reverse.pop(), MODELS.more_reverse.pop()]
              foreignReverses: [MODELS.foreign_reverse.pop()]
          link_tasks.push(link_task)

        for link_task in link_tasks then do (link_task) -> save_queue.defer (callback) ->
          link_task.owner.set(link_task.values)
          link_task.owner.save callback

        save_queue.await callback

      queue.await callback

    it 'Can fetch and serialize a custom foreign key', (done) ->
      Owner.findOne (err, test_model) ->
        assert.ok(!err, "No errors: #{err}")
        assert.ok(test_model, 'found model')

        test_model.get 'foreignReverses', (err, related_models) ->
          assert.ok(!err, "No errors: #{err}")
          assert.equal(1, related_models.length, "found related models. Expected: #{1}. Actual: #{related_models.length}")

          for related_model in related_models
            related_json = related_model.toJSON()
            assert.equal(test_model.id, related_json.ownerish_id, "Serialized the foreign id. Expected: #{test_model.id}. Actual: #{related_json.ownerish_id}")
          done()

    it 'Can create a model and load a related model by id (hasMany)', (done) ->
      Reverse.cursor({$values: 'id'}).limit(4).toJSON (err, reverse_ids) ->
        assert.ok(!err, "No errors: #{err}")
        assert.equal(4, reverse_ids.length, "found 4 reverses. Actual: #{reverse_ids.length}")

        new_model = new Owner()
        new_model.save (err) ->
          assert.ok(!err, "No errors: #{err}")
          new_model.set({reverses: reverse_ids})
          new_model.get 'reverses', (err, reverses) ->
            assert.ok(!err, "No errors: #{err}")
            assert.equal(4, reverses.length, "found 4 related model. Actual: #{reverses.length}")
            assert.equal(_.difference(reverse_ids, (test.id for test in reverses)).length, 0, "expected owners: #{_.difference(reverse_ids, (test.id for test in reverses))}")
            done()

    it 'Can create a model and load a related model by id (hasMany)', (done) ->
      Reverse.cursor({$values: 'id'}).limit(4).toJSON (err, reverse_ids) ->
        assert.ok(!err, "No errors: #{err}")
        assert.equal(4, reverse_ids.length, "found 4 reverses. Actual: #{reverse_ids.length}")

        new_model = new Owner()
        new_model.save (err) ->
          assert.ok(!err, "No errors: #{err}")
          new_model.set({reverse_ids: reverse_ids})
          new_model.get 'reverses', (err, reverses) ->
            assert.ok(!err, "No errors: #{err}")
            assert.equal(4, reverses.length, "found 4 related model. Actual: #{reverses.length}")
            assert.equal(_.difference(reverse_ids, (test.id for test in reverses)).length, 0, "expected owners: #{_.difference(reverse_ids, (test.id for test in reverses))}")
            done()

    it 'Can create a model and load a related model by id (belongsTo)', (done) ->
      Owner.cursor({$values: 'id'}).limit(4).toJSON (err, owner_ids) ->
        assert.ok(!err, "No errors: #{err}")
        assert.equal(4, owner_ids.length, "found 4 owners. Actual: #{owner_ids.length}")

        new_model = new Reverse()
        new_model.save (err) ->
          assert.ok(!err, "No errors: #{err}")
          new_model.set({owner: owner_ids[0]})
          new_model.get 'owner', (err, owner) ->
            assert.ok(!err, "No errors: #{err}")
            assert.ok(owner, 'loaded a model')
            assert.equal(owner_ids[0], owner.id, "loaded correct model. Expected: #{owner_ids[0]}. Actual: #{owner.id}")
            done()

    it 'Can create a model and load a related model by id (belongsTo)', (done) ->
      Owner.cursor({$values: 'id'}).limit(4).toJSON (err, owner_ids) ->
        assert.ok(!err, "No errors: #{err}")
        assert.equal(4, owner_ids.length, "found 4 owners. Actual: #{owner_ids.length}")

        new_model = new Reverse()
        new_model.save (err) ->
          assert.ok(!err, "No errors: #{err}")
          new_model.set({owner_id: owner_ids[0]})
          new_model.get 'owner', (err, owner) ->
            assert.ok(!err, "No errors: #{err}")
            assert.ok(owner, 'loaded a model')
            assert.equal(owner_ids[0], owner.id, "loaded correct model. Expected: #{owner_ids[0]}. Actual: #{owner.id}")
            done()
