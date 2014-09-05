events = require 'events'
nock   = require 'nock'
io     =
  server: require 'socket.io'

{expect} = require './chai'

{Subscription} = require '../feeds/subscriptions'

port = process.env.TEST_SOCKET_PORT ? 6789

describe 'feeds', ->
  @timeout 1500

  subs = null
  fire = null
  data = null

  createNock = ->
    nock('http://test.local')
      .filteringRequestBody(/.*/, '*')
      .post('/endpoint', '*')

  beforeEach ->
    subs = new Subscription
    fire = ->
      subs.emit('test', data)

  describe 'subscribers', ->

    describe '.callback()', ->
      it 'should support callbacks', ->
        expect(subs).to.have.property('callback')

      it 'should register callbacks', (done) ->
        callback = (args) ->
          expect(args).to.deep.equal(data)
          done()
        subs.callback('test', callback)
        fire()

      it 'should unregister callbacks', (done) ->
        callback = (args) ->
          expect.to.fail('does not unregister callbacks')
        stop = subs.callback('test', callback)
        stop()
        fire()
        setTimeout done, 100

    describe '.endpoint()', ->
      nocks = null

      beforeEach ->
        nocks = createNock()

      afterEach ->
        nock.cleanAll()

      it 'should support endpoints', ->
        expect(subs).to.have.property('endpoint')

      it 'should support https'

      it 'should register endpoints', (done) ->
        nocks.reply 200, (uri, requestBody) ->
          json = JSON.parse(requestBody)
          expect(json).to.deep.equal(data)
          done()
        subs.endpoint('test', 'http://test.local/endpoint')
        fire()

      it 'should unregister endpoints', (done) ->
        nocks.reply 200, (uri, requestBody) ->
          done('did not unregister endpoint')
        stop = subs.endpoint('test', 'http://test.local/endpoint')
        stop()
        fire()
        setTimeout(done, 100)

    describe '.socket()', ->
      server = null

      beforeEach ->
        server = io.server(port, log: false)

      afterEach ->
        server.close()

      it 'should support sockets', ->
        expect(subs).to.have.property('socket')

      it 'should register sockets', (done) ->
        server.on 'connect', (client) ->
          client.on 'test', (args) ->
            expect(args).to.deep.equal(data)
            done()

          fire()

        subs.socket('test', "http://localhost:#{port}")

      it 'should unregister sockets', (done) ->
        server.on 'connection', (client) ->
          client.on 'test', (args) ->
            should.fail('did not unregister socket')

          fire()
          setTimeout(done, 100)

        stop = subs.socket('test', "http://localhost:#{port}")
        stop()
