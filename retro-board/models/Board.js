const mongoose = require('mongoose')
const Schema = mongoose.Schema
const Message = require('./Message')


const Lane = new Schema({
	heading: {
		type: String,
		trim: true,
		required: [true, 'lanes need heads']
	},
	messages: {
		type: [Message],
		default: []
	}
})

const BoardSchema = new Schema({
	createrId: {
		type: String,
		required: true
	},
	name: {
		type: String,
		default: "untitled"
	},
	date: {
		type: Date,
		default: Date.now
	},
	lanes: [Lane]
})

module.exports = BoardSchema