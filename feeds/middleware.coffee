instances = require './instances'

module.exports =
  load: (req, res, next) ->
    req.feed = instances[req.params.feed]
    next if req.feed then null else "No feed!"

  pagination:
    page: (req, res, next) ->
      {page, page_size} = req.query
      req.pagination = req.feed.query page, page_size
      next()

    slice: (req, res, next) ->
      {from, to} = req.query
      req.pagination = req.feed.slice from, to
      next()

    query: (req, res, next) ->
      {offset, count} = req.query
      req.pagination = req.feed.query offset, count
      next()

    range: (req, res, next) ->
      req.pagination = req.query
      next()

