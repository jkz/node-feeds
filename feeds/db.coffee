redis = require 'then-redis'

url = process.env.REDIS_URL ? process.env.REDISTOGO_URL ? process.env.REDISCLOUD_URL ? 'http://127.0.0.1:6379'

module.exports = db = redis.createClient url
