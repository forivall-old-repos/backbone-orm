assert = assert or require?('chai').assert

BackboneORM = window?.BackboneORM; try BackboneORM or= require?('backbone-orm') catch; try BackboneORM or= require?('../../../../backbone-orm')
{_, Backbone, Queue, Utils, Fabricator} = BackboneORM

option_sets = window?.__test__option_sets or require?('../../../option_sets')
parameters = __test__parameters if __test__parameters?
_.each option_sets, exports = (options) ->
  return if options.embed
  options = _.extend({}, options, parameters) if parameters

  DATABASE_URL = options.database_url or ''
  BASE_SCHEMA = options.schema or {}
  SYNC = options.sync
  BASE_COUNT = 5

  describe "Backbone Events #{options.$parameter_tags or ''}#{options.$tags}", ->

    Reverse = Owner = null
    attribute_change_count = 0
    reset_change_count = 0
    before ->
      class Reverse extends Backbone.Model
        urlRoot: "#{DATABASE_URL}/reverses"
        schema: _.defaults({
          owners: -> ['hasMany', Owner]
        }, BASE_SCHEMA)
        sync: SYNC(Reverse)

      class Owner extends Backbone.Model
        urlRoot: "#{DATABASE_URL}/owners"
        schema: _.defaults({
          reverses: -> ['hasMany', Reverse]
        }, BASE_SCHEMA)
        sync: SYNC(Owner)

        initialize: ->
          super
          @on 'change:reverses', -> attribute_change_count++
          @get('reverses').on 'reset', -> reset_change_count++

    after (callback) -> Utils.resetSchemas [Reverse, Owner], (err) -> BackboneORM.model_cache.reset(); callback(err)
    after -> Reverse = Owner = null

    beforeEach (callback) ->
      BackboneORM.configure({model_cache: {enabled: !!options.cache, max: 100}})
      Utils.resetSchemas [Reverse, Owner], callback

    afterEach ->
      @main?.off()
      attribute_change_count = 0
      reset_change_count = 0

    # https://github.com/vidigami/backbone-mongo/issues/4
    it 'Triggering: should trigger by all permutations', (done) ->
      attribute_change_count = 0
      reset_change_count = 0

      assert.equal(attribute_change_count, 0)
      assert.equal(reset_change_count, 0)

      main = @main = new Owner()
      many = new Reverse({foo: 'bar'})
      assert.equal(attribute_change_count, 0)
      assert.equal(reset_change_count, 0)

      main.set('reverses', [many]);
      assert.equal(attribute_change_count, 0)
      assert.equal(reset_change_count, 1)

      manyCollection = main.get('reverses')
      manyCollection.push(many)
      main.set('reverses', manyCollection)
      assert.equal(attribute_change_count, 0)
      assert.equal(reset_change_count, 2)

      main.set('reverses', [many])
      assert.equal(attribute_change_count, 0)
      assert.equal(reset_change_count, 3)

      done()
