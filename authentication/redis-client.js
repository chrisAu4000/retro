const redis = require('redis')
const { promisify } = require('util')
const client = redis.createClient(process.env.REDIS_URL)

module.exports = {
	get: promisify(client.get).bind(client),
	set: promisify(client.set).bind(client),
	keys: promisify(client.keys).bind(client)
}