events    = require 'events'
uuid      = require 'uuid'
promise   = require 'promise'
db        = require './db'
instances = require './instances'

identity = (x) -> x

class Feed extends events.EventEmitter
  constructor: (@name, options={}) ->
    @key     = "feeds:#{@name}"

    @db      = options.db ? db

    # TODO fetch config from db
    @limit   = options.limit ? 20
    @timeout = options.timeout ? null

  validate: identity
  serialize: identity
  deserialize: identity

  entryKey: (id) =>
    "#{@key}:#{id}"

  generateId: (entry) =>
    uuid.v4()

  find: (id) =>
    db.get @entryKey(id)
      .then @deserialize

  add: (entry, {id, timeout, timestamp}={}) =>
    id        ?= @generateId entry
    timeout   ?= @timeout
    timestamp ?= new Date().getTime()

    key = @entryKey(id)

    promise
      .resolve entry
      .then @validate
      .then @serialize
      .then (serialized) ->
        db.multi()
        db.zadd @key, timestamp, id
        db.set key, serialized
        db.expire key, timeout if timeout
        db.exec()
      .then =>
        @emit 'entry', {id, entry}
        {id, entry}

  entries: (ids) =>
    db.mget (@entryKey(id) for id in ids)...
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

    db.zrangebyscore @key, min, max, 'LIMIT', offset, count

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

create = ({type, name, options}={}) ->
  throw "No name!" unless name

  Class = switch type
    when 'json' then JSONFeed
    else Feed

  # TODO store in db

  instances[name] = new Class(name, options)

module.exports = {Feed, JSONFeed, create}
