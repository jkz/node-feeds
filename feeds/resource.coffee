models    = require './models'
instances = require './instances'

module.exports =
  index: (req, res, next) ->
    res.json feeds: (instance for instance of instances)

  create: (req, res, next) ->
    models.create req.body
    res.json success: true

  show: (req, res, next) ->
    # TODO return pagination next/prev
    req.feed
      .range(req.pagination)
      .then (entries) ->
        res.json {entries}
      .catch next

  add: (req, res, next) ->
    req.feed
      .add(req.body)
      .then ({id}) ->
        res.json success: true, id: id
      .catch next

  find: (req, res, next) ->
    {entry} = req.params

    req.feed
      .find entry
      .then (entry) ->
        res.json {entry}
      .catch next


