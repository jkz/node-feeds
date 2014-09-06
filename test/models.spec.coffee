promise  = require 'promise'
models   = require '../feeds/models'
db       = require '../feeds/db'
{expect} = require './chai'

describe 'models', ->
  describe 'Feed', ->
    feed = ids = entries = null

    populate = (done) ->
      feed = new models.Feed 'key'
      entry = (id) -> 'entry/' + id
      ids = ['a', 'b', 'c', 'd', 'e']
      entries = (entry(id) for id in ids)
      promise
        .all (feed.add entry(id), {id} for id in ids)
        .then ->
          done()

    clear = (done) ->
      feed.clear()
        .then ->
          feed = null
          done()
        .catch done


    describe '.constructor()', ->
      before ->
        feed = new models.Feed 'key'

      after clear

      it 'should have a key', ->
        expect(feed.key).to.equal("#{feed.constructor.prefix}/key")

    describe '.add()', ->

      beforeEach ->
        feed = new models.Feed 'test'

      afterEach clear

      it 'should use id', ->
        entry = id = 'id'
        timestamp = 1
        result = feed.add(entry, {id, timestamp})
        expect(result).to.become({id, entry, timestamp})

      it 'should provide default id', (done) ->
        entry = 'id'
        result = feed.add(entry).then ({id}) ->
          done if id then null else "id is not defined"

      it 'should add to index', ->
        entry = id = 'index'
        timestamp = 100

        result = feed
          .add entry, {id, timestamp}
          .then ->
            db.zscore(feed.key, id)
          .then parseInt

        expect(result).to.become(timestamp)

      it 'should add as key', ->
        entry = id = 'key'

        result = feed
          .add entry, {id}
          .then ->
            db.get feed.dataKey(id)

        expect(result).to.become(entry)

      it 'should expire keys', ->
        entry = id = 'ttl'
        timeout = 100
        result = feed
          .add entry, {id, timeout}
          .then ->
            db.ttl feed.dataKey(id)
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
            for entry in entries when entry
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

  describe 'ComboFeed', ->
    describe '.combine()', ->
      feed1 = feed2 = combo = null

      beforeEach ->
        feed1 = new models.Feed 'feed1'
        feed2 = new models.Feed 'feed2'
        combo = new models.ComboFeed 'combo'
        combo.combine feed1
        combo.combine feed2

      afterEach ->
        promise.all [
          feed1.clear()
          feed2.clear()
          combo.clear()
        ]

      it 'should propagate entry events', (done) ->
        result = promise
          .all([
            feed1.add 'first'
            feed2.add 'second'
          ])
          .then =>
            setTimeout ->
              combo
                .range()
                .then (entries) ->
                  expect(entries).to.deep.equal(['first', 'second'])
                  done()
                .catch done
            , 0


