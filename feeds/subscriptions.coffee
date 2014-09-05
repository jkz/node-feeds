events = require 'events'
http   = require 'http'
url    = require 'url'
io =
  client: require 'socket.io-client'

# The subscribers return unsubscribe functions
class Subscription
  constructor: (emitters) ->
    @emitters = []
    @emitter = new events.EventEmitter

    @add @emitter

    emitters = [emitters] if emitters?.on?
    @add emitter for emitter in emitters ? []

  add: (emitter) =>
    @emitters.push emitter

  on: (args...) =>
    emitter.on args... for emitter in @emitters

    => @off args...

  off: (args...) =>
    emitter.removeListener args... for emitter in @emitters

  emit: (args...) =>
    @emitter.emit args...

  callback: (args...) =>
    @on args...

  socket: (event, socket) =>
    socket = io.client socket unless socket.emit
    @on event, (data) ->
      socket.emit event, data

  endpoint: (event, endpoint, options={}) =>
    {host, path, port} = url.parse endpoint

    options.hostname ?= host
    options.method   ?= 'POST'
    options.port     ?= port
    options.path     ?= path

    @on event, (data) ->
      req = http.request options
      req.write JSON.stringify data
      req.end()

  subscribe: (event, options={}) =>
    {callback, websocket, endpoint} = options

    offs = {}
    offs.callback = @callback event, callback if callback
    offs.socket = @callback event, socket if socket
    offs.endpoint = @callback event, endpoint, options.endpointOptions if endpoint
    offs

module.exports = {Subscription}
