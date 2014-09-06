events    = require 'events'
uuid      = require 'uuid'
promise   = require 'promise'

db        = require './db'
instances = require './instances'
subs      = require './subscriptions'

identity = (x) -> x

class Feed extends events.EventEmitter
  @prefix: '/feeds'

  @create: (name, options={}) ->
    throw "No name!" unless name
    # TODO store in db
    instances[name] = new this(name, options)

  constructor: (@name, options={}) ->
    @key     = "#{@constructor.prefix}/#{@name}"

    @db      = options.db ? db

    # TODO fetch config from db
    @limit   = options.limit ? 20
    @timeout = options.timeout ? null

    @validate = options.validate if options.validate
    @serialize = options.serialize if options.serialize
    @deserialize = options.deserialize if options.deserialize

    @sub = new subs.Subscription(this)

  # Remove all associated keys
  clear: =>
    return promise.reject "Won't wipe empty key!" unless @key

    db.keys @key + '*'
      .then (keys) =>
        db.del keys... if keys.length

  validate: identity
  serialize: identity
  deserialize: identity

  dataKey: (id) =>
    "#{@key}/#{id}"

  generateId: (entry) =>
    uuid.v4()

  generateTimestamp: (entry) =>
    new Date().getTime()

  find: (id) =>
    @db
      .get @dataKey(id)
      .then (entry) ->
        throw "No entry!" unless entry
        entry
      .then @deserialize

  persist: ({key, id, entry, timestamp}, {timeout}={}) =>
    @db.multi()
    @db.zadd @key, timestamp, id
    @db.set key, entry if key and entry
    @db.expire key, timeout if key and timeout
    @db.exec()
      .then ([isNew]) ->
        throw "Not new" unless parseInt(isNew)

  add: (entry, {id, timeout, timestamp}={}) =>
    id        ?= @generateId entry
    timestamp ?= @generateTimestamp entry
    timeout   ?= @timeout

    key = @dataKey(id)

    validate = (entry) =>
      @validate entry
      entry

    promise
      .resolve entry
      .then validate
      .then @serialize
      .then (entry) =>
        @persist {key, id, entry, timestamp}, {timeout}
      .then =>
        @emit 'entry', {id, entry, timestamp}
        {id, entry, timestamp}

  entries: (ids) =>
    @db
      .mget (@dataKey(id) for id in ids)...
      .then (entries) =>
        @deserialize(entry) for entry in entries
      .catch (err) ->
        return [] if "#{err}" == "Error: ERR wrong number of arguments for 'mget' command"
        throw err

  index: ({offset, count, min, max, older, newer}={}) =>
    offset ?= 0
    count  ?= @limit
    min    ?= '-inf'
    max    ?= '+inf'

    min = '(' + min if newer and min isnt '-inf'
    max = '(' + max if older and max isnt '+inf'

    db.zrevrangebyscore @key, max, min, 'LIMIT', offset, count

  range: (options) =>
    @index(options).then(@entries)

  slice: (offset=0, end) =>
    end ?= offset + @limit
    count = end - offset
    {offset, count}

  query: (offset=0, count) ->
    {offset, count}

  page: (index=1, count) =>
    count ?= @limit
    offset = (index - 1) * count
    {offset, count}

  newer: (min, options={}) =>
    options.newer = true
    options.min = min
    options

  older: (max, options={}) =>
    options.older = true
    options.max = max
    options

  between: (min, max, options={}) ->
    options.newer = true
    options.older = true
    options.min = min
    options.max = max
    options

  older: (max, options={}) =>
    options.older = true
    options.max = max
    options

class JSONFeed extends Feed
  # TODO maybe we don't want to serialize twice per entry :-)
  validate: (entry) ->
    @serialize(entry)
    entry
  serialize: JSON.stringify
  deserialize: JSON.parse

# Combine multiple feeds in to a single one
class ComboFeed extends Feed
  # No need for entry key as it is already stored by another feed
  dataKey: identity

  # TODO We might want to validate somewhere else
  validate: ->
    true

  # Add another feed. Use the data key for id.
  combine: (other) =>
    other.on 'entry', ({id, timestamp}) =>
      id = other.dataKey(id)
      @add null, {id, timestamp}

module.exports = {Feed, JSONFeed, ComboFeed}
