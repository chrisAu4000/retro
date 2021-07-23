const mongoose = require('mongoose')

const connect = async () => {
	return await mongoose.connect(process.env.MONGO_URL, { useNewUrlParser: true, useUnifiedTopology: true })
}

const disconnect = async () => {
	return await mongoose.close()
}

module.exports = { connect, disconnect }