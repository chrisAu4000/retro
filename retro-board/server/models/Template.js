const mongoose = require('mongoose')
const Schema = mongoose.Schema

const Lane = new Schema({
	heading: {
		type: String,
		trim: true,
		required: [true, 'lanes need heads']
	}
})

const TemplateSchema = new Schema({
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

module.exports = TemplateSchema