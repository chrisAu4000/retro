const mongoose = require('mongoose')
const Schema = mongoose.Schema

const MessageSchema = new Schema({
	createrId: {
		type: String,
		trim: true,
		required: true
	},
	boardId: {
		type: String,
		trim: true,
		required: true
	},
	text: {
		type: String,
		trim: false,
	},
	upvotes: {
		type: Number,
		default: 0
	},
	type: {
		type: String,
		enum: ['Item', 'Action'],
		default: 'Item'
	}
})

const MessageStackSchema = new Schema({
	messages: [MessageSchema]
})

module.exports = {
	messageSchema: MessageSchema,
	messageStackSchema: MessageStackSchema
}