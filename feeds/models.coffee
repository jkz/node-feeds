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
    throw new Error "No name!" unless name
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
    @render = options.render if options.render

    @sub = new subs.Subscription(this)

  # Remove all associated keys
  clear: =>
    return promise.reject "Won't wipe empty key!" unless @key

    db.keys @key + '*'
      .then (keys) =>
        db.del keys... if keys.length

  # Throw an error when not valid
  validate: identity
  # From internal to disk
  serialize: identity
  # From disk to internal
  deserialize: identity
  # From internal to external
  render: ({id, data, timestamp}) -> data
  # From external to internal
  parse: (blob) -> blob


  dataKey: (id) =>
    "#{@key}/#{id}"

  generateId: (data) =>
    uuid.v4()

  generateTimestamp: (data) =>
    new Date().getTime()

  store: ({id, data, timestamp, timeout}) =>
    @db.multi()
    @db.zadd @key, timestamp, id
    @db.set key, data if data
    @db.expire key, timeout if timeout
    @db.exec()
      .then ([isNew]) =>
        throw new Error "Not new" unless parseInt(isNew)

  save: ({id, data, timestamp, timeout, key}) =>
    key     ?= @dataKey id
    timeout ?= @timeout

    @db.multi()
    @db.zadd @key, timestamp, id
    @db.set key, data if data
    @db.expire key, timeout if timeout
    @db.exec()
      .then ([isNew]) =>
        throw new Error "Not new" unless parseInt(isNew)

  send: ({id, data, timestamp}) =>
    render = @render {id, data, timestamp}
    @emit 'data', {id, data, timestamp, render}

  add: (raw, {id, timeout, timestamp, key}={}) =>
    data      = raw and @parse raw
    id        ?= @generateId data
    timestamp ?= @generateTimestamp data

    chain =
      if not data
        promise.resolve null
      else
        promise
          .resolve()
          .then =>
            @validate data
          .then =>
            @serialize data
    chain
      .then (data) =>
        @save {id, data, timestamp, timeout}
      .then =>
        @send {id, data, timestamp}
      .then =>
        {id, data, timestamp}

  find: (id) =>
    @db.multi()
    @db.get @dataKey(id)
    @db.zscore @key, id
    @db.exec()
      .then ([serialized, timestamp]) =>
        throw new Error "Not found!" unless serialized and timestamp
        data = @deserialize(serialized)
        @render {id, data, timestamp}

  entries: (ids) =>
    return promise.reject new Error "No ids" unless ids.length

    @db.multi()
    @db.mget (@dataKey(id) for id in ids)...
    @db.zscore @key, id for id in ids
    @db.exec()
      .then ([datas, timestamps...]) =>
        for id, i in ids
          data = @deserialize(datas[i])
          timestamp = timestamps[i]
          @render {id, data, timestamp}

  index: ({offset, count, min, max, older, newer}={}) =>
    offset ?= 0
    count  ?= @limit
    min    ?= '-inf'
    max    ?= '+inf'

    min = '(' + min if newer and min isnt '-inf'
    max = '(' + max if older and max isnt '+inf'

    chain = db
      .zrevrangebyscore @key, max, min, 'WITHSCORES', 'LIMIT', offset, count
      .then (entries) =>
        id: id, timestamp: entries[i + 1] for id, i in entries by 2

  range: (options={}) =>
    {timestamps} = options

    @index(options)
      .then (refs) =>
        @db.mget (@dataKey(ref.id) for ref in refs)...
          .then (datas) =>
            for ref, i in refs
              @render
                id: ref.id
                data: @deserialize(datas[i])
                timestamp: ref.timestamp

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
  validate: (data) ->
    @serialize(data)
    data
  serialize: JSON.stringify
  deserialize: JSON.parse

# Combine multiple feeds in to a single one
class ComboFeed extends Feed
  # No need for entry key as it is already stored by another feed
  dataKey: identity

  render: ({id, data, timestamp}) ->
    {id, data, timestamp}

  # TODO We might want to validate somewhere else
  validate: ->
    true

  # Whenever an entry is added to the other feed, create a reference to it
  # with the data key and timestamp. Then reemit the data.
  combine: (other) =>
    other.on 'data', ({id, data, timestamp}) =>
      id = other.dataKey(id)
      @save {id, timestamp}
        .then =>
          @send {id, data, timestamp}

module.exports = {Feed, JSONFeed, ComboFeed}
