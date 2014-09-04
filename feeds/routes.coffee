express    = require 'express'

middleware = require './middleware'
resource   = require './resource'

module.exports = app = express()

app.get '/', resource.index
app.post '/', resource.create

app.get '/:feed', [
  middleware.load
  middleware.pagination.range
], resource.show

app.post '/:feed', [
  middleware.load
], resource.add

app.get '/:feed/:entry', [
  middleware.load
], resource.find
