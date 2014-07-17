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

  describe "Model.page #{options.$parameter_tags or ''}#{options.$tags}", ->

    Flat = null
    before ->
      class Flat extends Backbone.Model
        urlRoot: "#{DATABASE_URL}/flats"
        schema: BASE_SCHEMA
        sync: SYNC(Flat)

    after (callback) ->
      queue = new Queue()
      queue.defer (callback) -> ModelCache.reset(callback)
      queue.defer (callback) -> Utils.resetSchemas [Flat], callback
      queue.await callback
    after -> Flat = null

    beforeEach (done) ->
      queue = new Queue(1)
      queue.defer (callback) -> ModelCache.configure({enabled: !!options.cache, max: 100}, callback)
      queue.defer (callback) -> Utils.resetSchemas [Flat], callback
      queue.defer (callback) -> Fabricator.create(Flat, BASE_COUNT, {
        name: Fabricator.uniqueId('flat_')
        created_at: Fabricator.date
        updated_at: Fabricator.date
      }, callback)
      queue.await done

    it 'Cursor can chain limit with paging', (done) ->
      LIMIT = 3
      Flat.cursor({$page: true}).limit(LIMIT).toJSON (err, data) ->
        assert.ifError(err)
        assert.ok(data.rows, 'models received')
        assert.equal(data.total_rows, BASE_COUNT, 'has the correct total_rows')
        assert.equal(LIMIT, data.rows.length, "\nExpected: #{LIMIT}, Actual: #{data.rows.length}")
        done()

    it 'Cursor can chain limit without paging', (done) ->
      LIMIT = 3
      Flat.cursor({$page: false}).limit(LIMIT).toJSON (err, data) ->
        assert.ifError(err)
        assert.equal(LIMIT, data.length, "\nExpected: #{LIMIT}, Actual: #{data.length}")
        done()

    it 'Cursor can chain limit and offset with paging', (done) ->
      LIMIT = 3; OFFSET = 1
      Flat.cursor({$page: true}).limit(LIMIT).offset(OFFSET).toJSON (err, data) ->
        assert.ifError(err)
        assert.ok(data.rows, 'models received')
        assert.equal(data.total_rows, BASE_COUNT, 'has the correct total_rows')
        assert.equal(OFFSET, data.offset, 'has the correct offset')
        assert.equal(LIMIT, data.rows.length, "\nExpected: #{LIMIT}, Actual: #{data.rows.length}")
        done()

    it 'Cursor can chain limit with paging (no true or false)', (done) ->
      LIMIT = 3; OFFSET = 1
      Flat.cursor({$page: ''}).limit(LIMIT).offset(OFFSET).toJSON (err, data) ->
        assert.ifError(err)
        assert.ok(data.rows, 'models received')
        assert.equal(data.total_rows, BASE_COUNT, 'has the correct total_rows')
        assert.equal(OFFSET, data.offset, 'has the correct offset')
        assert.equal(LIMIT, data.rows.length, "\nExpected: #{LIMIT}, Actual: #{data.rows.length}")
        done()

    it 'Cursor can select fields with paging', (done) ->
      FIELD_NAMES = ['id', 'name']
      Flat.cursor({$page: true}).select(FIELD_NAMES).toJSON (err, data) ->
        assert.ifError(err)
        assert.ok(_.isArray(data.rows), 'models received')
        for json in data.rows
          assert.equal(_.size(json), FIELD_NAMES.length, 'gets only the requested values')
        done()

    it 'Cursor can select values with paging', (done) ->
      FIELD_NAMES = ['id', 'name']
      Flat.cursor({$page: true}).values(FIELD_NAMES).toJSON (err, data) ->
        assert.ifError(err)
        assert.ok(_.isArray(data.rows), 'cursor values is an array')
        for json in data.rows
          assert.ok(_.isArray(json), 'cursor data values is an array')
          assert.equal(json.length, FIELD_NAMES.length, 'gets only the requested values')
        done()

    it 'Ensure the correct value is returned', (done) ->
      Flat.findOne (err, model) ->
        assert.ifError(err)
        assert.ok(!!model, 'model')
        Flat.cursor({$page: true, name: model.get('name')}).toJSON (err, data) ->
          assert.ifError(err)
          assert.equal(data.total_rows, 1, 'has the correct total_rows')
          assert.equal(data.rows.length, 1, 'has the correct row.length')
          assert.deepEqual(expected = model.toJSON().id, actual = data.rows[0].id, "\nExpected: #{JSONUtils.stringify(expected)}\nActual: #{JSONUtils.stringify(actual)}")
          done()

    it 'Ensure paging of one always returns an array of one', (done) ->
      LIMIT = 3; OFFSET = 1
      Flat.cursor({$page: '', $one: true}).limit(LIMIT).offset(OFFSET).toJSON (err, data) ->
        assert.ifError(err)
        assert.ok(data.rows, 'models received')
        assert.equal(data.total_rows, BASE_COUNT, 'has the correct total_rows')
        assert.equal(OFFSET, data.offset, 'has the correct offset')
        assert.equal(1, data.rows.length, "\nExpected: #{LIMIT}, Actual: #{data.rows.length}")
        done()