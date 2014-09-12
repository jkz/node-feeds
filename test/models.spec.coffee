promise  = require 'promise'
models   = require '../feeds/models'
db       = require '../feeds/db'
{expect} = require './chai'

describe 'models', ->
  describe 'Feed', ->
    feed = ids = entries = null

    populate = ->
      feed = new models.Feed 'key'
      entry = (id) -> 'data/' + id
      ids = ['a', 'b', 'c', 'd', 'e']
      entries = (entry(id) for id in ids)
      promise.all (feed.add entry(id), {id} for id in ids)

    clear = ->
      feed
        .clear()
        .then ->
            feed = null


    describe '.constructor()', ->
      before ->
        feed = new models.Feed 'key'

      after clear

      it 'should have a key', ->
        expect(feed.key).to.equal("/key")

    describe '.add()', ->

      beforeEach ->
        feed = new models.Feed 'test'

      afterEach clear

      it 'should use id', ->
        data = id = 'id'
        timestamp = 1
        result = feed.add(data, {id, timestamp})
        expect(result).to.become({id, data, timestamp})

      it 'should provide default id', (done) ->
        data = 'id'
        result = feed.add(data).then (id) ->
          done if id then null else "id is not defined"

      it 'should add to index', ->
        data = id = 'index'
        timestamp = 100

        result = feed
          .add data, {id, timestamp}
          .then ->
            db.zscore(feed.key, id)
          .then parseInt

        expect(result).to.become(timestamp)

      it 'should add as key', ->
        data = id = 'key'

        result = feed
          .add data, {id}
          .then ->
            db.get feed.dataKey(id)

        expect(result).to.become(data)

      it 'should expire keys', ->
        data = id = 'ttl'
        timeout = 100
        result = feed
          .add data, {id, timeout}
          .then ->
            db.ttl feed.dataKey(id)
        expect(result).to.eventually.be.above(0)

      it 'should emit entries', (done) ->
        feed.on 'data', ->
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

    describe '.clear()', ->
      before populate
      after clear

      it 'should delete all associated keys', ->
        feed
          .index()
          .then (ids) ->
            feed
              .clear()
              .then ->
                feed.entries(ids)
          .then (entries) ->
            for data in entries when data
              return throw new Error "Entries remaining"
          .then ->
            feed.index()
          .then (ids) ->
            throw new Error "Ids remaining" if ids.length

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

  describe 'Aggregator', ->
    describe '.combine()', ->
      feed1 = feed2 = combo = null

      beforeEach ->
        feed1 = new models.Feed 'feed1'
        feed2 = new models.Feed 'feed2'
        combo = new models.Aggregator 'combo', render: ({data}) -> data
        combo.combine feed1
        combo.combine feed2

      afterEach ->
        promise.all [
          feed1.clear()
          feed2.clear()
          combo.clear()
        ]

      it 'should propagate data events', (done) ->
        id = timestamp = 1
        data = 'data'

        combo.on 'data', (actual) ->
          done try
            expect(actual).to.deep.equal
              id: '/feed1/' + id
              data: data
              timestamp: timestamp
              render: data
            null
          catch e
            e

        feed1
          .add data, {id, timestamp}
          .catch (err) ->
            done err


      it 'should combine multiple feeds', (done) ->
        entries = ['first', 'second']
        results = []

        combo.on 'data', ({id}) ->
          results.unshift entries.shift()
          return if entries.length

          combo
            .range()
            .then (entries) ->
              expect(entries).to.deep.equal(results)
            .then ->
              done()
            .catch (err) ->
              done err

        promise.all [
          feed1.add entries[0]
          feed2.add entries[1]
        ]
