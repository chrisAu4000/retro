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
	}
})

const ActionSchema = new Schema({
	boardId: {
		type: String,
		trim: true,
		required: true
	},
	text: {
		type: String,
		trim: false,
	}
})

const MessageStackSchema = new Schema({
	messages: [MessageSchema],
	actions: [ActionSchema]
})

module.exports = {
	messageSchema: MessageSchema,
	actionSchema: ActionSchema,
	messageStackSchema: MessageStackSchema
}