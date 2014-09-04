promise = require 'node-promise'
models = require '../feeds/models'
db = require '../feeds/db'

{expect} = require './chai'

describe 'models', ->
  describe 'Feed', ->
    feed = ids = entries = null

    populate = (done) ->
      feed = new models.Feed 'key'
      entry = (id) -> 'entry:' + id
      ids = ['a', 'b', 'c', 'd', 'e']
      entries = (entry(id) for id in ids)
      promise
        .all (feed.add entry(id), {id} for id in ids)
        .then ->
          done()

    clear = (done) ->
      if feed.key
        db.keys feed.key + '*'
          .then (keys) ->
            db.del keys... if keys.length
          .then ->
            done()

      feed = null


    describe '.constructor()', ->
      before ->
        feed = new models.Feed 'key'

      after clear

      it 'should have a key', ->
        expect(feed.key).to.equal('feeds:key')

    describe '.add()', ->

      beforeEach ->
        feed = new models.Feed 'test'

      afterEach clear

      it 'should use id', ->
        entry = id = 'id'
        result = feed.add(entry, {id})
        expect(result).to.become({id, entry})

      it 'should provide default id', (done) ->
        entry = 'id'
        result = feed.add(entry).then ({id}) ->
          done if id then null else "id is not defined"

      it 'should add to index', ->
        entry = id = 'index'
        timestamp = 1
        feed.add entry, {id, timestamp}

        result = db.zscore(feed.key, id).then(parseInt)
        expect(result).to.become(timestamp)

      it 'should add as key', ->
        entry = id = 'key'
        feed.add entry, {id}

        result = db.get feed.entryKey(id)
        expect(result).to.become(entry)

      it 'should expire keys', ->
        entry = id = 'ttl'
        timeout = 100
        feed.add entry, {id, timeout}

        result = db.ttl feed.entryKey(id)
        expect(result).to.eventually.be.above(0)

      it 'should emit entries', (done) ->
        feed.on 'entry', ->
          done()

        feed.add 'emit'

    describe '.index()', ->
      ids = null
      entries = null

      before (done) ->
        feed = new models.Feed 'index'
        ids = ['a', 'b', 'c']
        promise
          .all (feed.add id, {id} for id in ids)
          .then ->
            done()

      after clear

      it 'should return a range of ids', ->
        result = feed.index(count: 3)
        expect(result).to.become(ids)

        result = feed.index(count: 4)
        expect(result).to.become(ids)

        result = feed.index()
        expect(result).to.become(ids)

        result = feed.index(count: 2)
        expect(result).to.become(ids[0..1])

        result = feed.index(count: 2, offset: 1)
        expect(result).to.become(ids[1..2])

        result = feed.index(min: 1)
        expect(result).to.become(ids[1..2])

        result = feed.index(min: 1, newer: true)
        expect(result).to.become([ids[2]])

        result = feed.index(max: 1)
        expect(result).to.become(ids[0..1])

        result = feed.index(max: 1, older: true)
        expect(result).to.become([ids[0]])

        result = feed.index(min: 1, max: 3, older: true, newer: true)
        expect(result).to.become([ids[1]])

        return

    describe '.entries()', ->
      before populate
      after clear

      it 'should return a range of entries', ->
        result = feed.entries(ids)
        expect(result).to.become(entries)

    describe '.range()', ->
      before populate
      after clear

      it 'should return entries by ids', ->
        result = feed.entries(ids)
        expect(result).to.become(entries)

    describe '.slice()', ->
      before populate
      after clear

      it 'should return a range of entries', ->
        actual = feed.slice(0, 2)
        expected =
          offset: 0
          count: 2

        expect(actual).to.deep.equal(expected)

        actual = feed.slice(1, 3)
        expected =
          offset: 1
          count: 2
        expect(actual).to.deep.equal(expected)

    describe '.query()', ->
      before populate
      after clear

      it 'should return a range of entries', ->
        actual = feed.query(0, 2)
        expected =
          offset: 0
          count: 2

        expect(actual).to.deep.equal(expected)

        actual = feed.query(1, 3)
        expected =
          offset: 1
          count: 3
        expect(actual).to.deep.equal(expected)



    describe '.page()', ->
    describe '.newer()', ->
    describe '.older()', ->
