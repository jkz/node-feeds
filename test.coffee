express = require 'express'
bodyParser = require 'body-parser'

feeds = require './feeds'

feeds.models.create
  type: 'json'
  name: 'messages'

port = process.env.PORT ? 0xf3d ? 0xfeed

app = express()
app.use bodyParser.json()
app.use '/feeds', feeds.routes

app.listen port, ->
  console.log "Listening on #{port}"
