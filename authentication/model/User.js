const Schema = require('mongoose').Schema

const user = {
	firstName: {
		type: String,
		trim: true,
		required: [true, 'first name is required']
	},
	lastName: {
		type: String,
		trim: true
	},
	email: {
		type: String,
		trim: true,
		unique: [true, 'email is required']
	},
	password: {
		type: String,
		trim: true,
		required: [true, 'password is required']
	},
	role: {
		type: String,
		trim: true
	}
}

module.exports = new Schema(user)