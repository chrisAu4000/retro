const path = require('path')
const crypto = require('crypto')
const Http = require('http')
const express = require('express')
const bodyParser = require('body-parser')
const exphbs = require('express-handlebars')
const cookieParser = require('cookie-parser')
const SocketIo = require('socket.io')
const redis = require('./redis-client')
const mongo = require('./mongo-client');
const templateSchema = require('./models/Template')
const boardSchema = require('./models/Board')
const { messageSchema, actionSchema, messageStackSchema } = require('./models/Message')

const app = express()
const http = Http.createServer(app);
const io = SocketIo(http)

/**
 * Generates a random token. Format is hex
 */
const genToken = () => crypto.randomBytes(30).toString('hex')
/**
 * Formates a date.
 */
const formatDate = (date) => date.toISOString().replace(/T/, ' ').replace(/\..+/, '')
/* Property name for the session id in cookie. */
const SESSION_ID = 'SessionId'

app.engine('hbs', exphbs({ extname: '.hbs' }))
app.set('view engine', 'hbs')
app.set('views', path.join(__dirname, '/views'))
app.set('trust proxy', 1)
app.use(bodyParser.urlencoded({ extended: false }))
app.use(bodyParser.json())
app.use(cookieParser())
app.use(express.static(path.join(__dirname, 'public')))
/**
 * Middleware
 * Sets the user property if possible.
 */
app.use('/', async (req, _, next) => {
	try {
		const token = req.cookies['AuthToken']
		if (!token) return next()
		const user = await redis.get(token)
		req.user = JSON.parse(user)
		next()
	} catch (err) {
		console.error(err)
		next()
	}
})
/**
 * Middleware
 * Sets boardId, sessionId and user if possible.
 */
io.use(async (socket, next) => {
	try {
		const token = socket.handshake.auth.authToken
		const boardId = socket.handshake.auth.boardId
		const sessionId = socket.handshake.auth.sessionId
		socket.boardId = boardId
		socket.sessionId = sessionId
		if (!token) return next()
		const user = await redis.get(token)
		socket.user = user
		next()
	} catch (err) {
		console.error(err)
	}
})
/**
 * Middleware
 * Checks if the user is set on req.
 * If user is not present res.redirect('/auth/login') will be called.
 */
const secure = (req, res, next) => {
	if (process.env.DEVELOPMENT === 'true') {
		req.user = { id: 'test-user' }
		return next()
	}
	if (req.user) {
		next()
	} else {
		res.redirect('/auth/login')
	}
}
/**
 * Middleware
 * Checks if the user is set on socket.
 * If user is not present an error will be thrown on socket.
 */
const socketSecure = (socket, next) => {
	if (socket.user) {
		next()
	} else {
		next(new Error('invalid user'))
	}
}

mongo.connect().then((connection) => {
	console.log('MongoDB Connected')
	const Template = connection.model('Template', templateSchema)
	const Board = connection.model('Board', boardSchema)
	const Message = connection.model('Message', messageSchema)
	const Action = connection.model('Action', actionSchema)
	const MessageStack = connection.model('MessageStack', messageStackSchema)
	/**
	 * Query to a message
	 * boardId: the id of the board where the message is.
	 * laneId: the id of the lane in which the message is.
	 * stackId: the id of the message stack in which the message is
	 * messageId: the id of the message
	 */
	const queryMessage = (boardId, laneId, stackId, messageId) => ({
		"_id": boardId,
		"lanes": {
			"$elemMatch": {
				"_id": laneId,
				"stacks": {
					"$elemMatch": {
						"_id": stackId,
						"messages": {
							"$elemMatch": {
								"_id": messageId
							}
						}
					}
				}
			}
		}
	})
	/**
	 * Query to message stack
	 * boardId: the id of the board where the message stack is.
	 * laneId: the id of the lane in which the message stack is.
	 * stackId: the id of the message stack
	 */
	const queryStack = (boardId, laneId, stackId) => ({
		"_id": boardId,
		"lanes": {
			"$elemMatch": {
				"_id": laneId,
				"stacks": {
					"$elemMatch": {
						"_id": stackId
					}
				}
			}
		}
	})
	/**
	 * Query to action item text
	 * boardId: the id of the board where the action item is.
	 * laneId: the id of the lane in which the message stack of the action item is.
	 * stackId: the id of the message stack of the action item.
	 * actionId: the id of the action item.
	 */
	const queryActionText = (boardId, laneId, stackId, actionId) => ({
		"_id": boardId,
		"lanes": {
			"$elemMatch": {
				"_id": laneId,
				"stacks": {
					"$elemMatch": {
						"_id": stackId,
						"actions": {
							"$elemMatch": {
								"_id": actionId
							}
						}
					}
				}
			}
		}
	})
	/**
	 * Returns the lane, laneIndex and the stack and stackIndex of a stack with stackId.
	 * boardId: the id of the board that includes tha stack
	 * laneId: the id of the lane that includes the stack
	 * stackId: the id of the stack that should be found.
	 */
	const getStackData = async (boardId, laneId, stackId) => {
		const lanesDoc = await Board.findOne({ _id: boardId }, { lanes: 1 })
		return new Promise((res, rej) => {
			lanesDoc.lanes.map(async (lane, laneIndex) => {
				if (lane._id.toString() !== laneId) return
				lane.stacks.map(async (stack, stackIndex) => {
					if (stack._id.toString() !== stackId) return
					res({ lane, laneIndex, stack, stackIndex })
				})
			})
		})
	}
	/**
	 * Returns the lane, laneIndex, stack, stackIndex and actionitem and actionitemIndex of an actionItem with actionId.
	 * boardId: the id of the board that includes tha action item
	 * laneId: the id of the lane that includes the action item
	 * stackId: the id of the stack that includes the action item.
	 * actionId: the id of the action item that should be found.
	 */
	const getActionData = async (boardId, laneId, stackId, actionId) => {
		const { lane, laneIndex, stack, stackIndex } = await getStackData(boardId, laneId, stackId)
		return new Promise((res) => {
			stack.actions.map(async (action, actionIndex) => {
				if (action._id.toString() !== actionId) return
				res({ lane, laneIndex, stack, stackIndex, action, actionIndex })
			})
		})
	}
	/**
	 * Returns the lane, laneIndex, stack, stackIndex and message and messageIndex of an message with messageId.
	 * boardId: the id of the board that includes tha action item
	 * laneId: the id of the lane that includes the action item
	 * stackId: the id of the stack that includes the action item.
	 * messageId: the id of the message that should be found.
	 */
	const getMessageData = async (boardId, laneId, stackId, messageId) => {
		const { lane, laneIndex, stack, stackIndex } = await getStackData(boardId, laneId, stackId)
		return new Promise((res) => {
			stack.messages.map(async (message, messageIndex) => {
				if (message._id.toString() !== messageId) return
				res({ lane, laneIndex, stack, stackIndex, message, messageIndex })
			})
		})
	}
	/**
	 * Creates an empty message
	 * createrId: the token of the user that creates this message.
	 * boardId: the id of the board on that the message should be created.
	 * laneId: the id of the lane on the board where the message should be created.
	 * message {optional}: the message that should be created. if undefined an empty message will be created.
	 */
	const createMessage = async (createrId, boardId, laneId, message) => {
		const board = await Board.findById(boardId)
		if (!board) throw new Error('Board: Not Found')
		const lane = await board.lanes.filter(lane => lane.id === laneId)[0]
		if (!lane) throw new Error('Lane: Not Found')
		if (message === undefined) {
			message = new Message({
				createrId: createrId,
				boardId: boardId,
				text: '',
				upvotes: 0
			})
		}
		const stack = new MessageStack({
			messages: [message]
		})
		lane.stacks.push(stack)
		return board.save()
	}
	/**
	 * Deletes a message. If the message is the only one on a stack, the whole stack will be removed.
	 * boardId: the id of the board where the message can be found
	 * laneId: the id of the lane on the board where the message can be found.
	 * stackId: the id of the stack that includes the message
	 * messageId: the id of the message that should be removed.
	 */
	const deleteMessage = async (boardId, laneId, stackId, messageId) => {
		const { stack } = await getStackData(boardId, laneId, stackId)
		if (stack.messages.length === 1) {
			return await Board.updateOne({
				"_id": boardId,
				"lanes._id": laneId
			}, {
				"$pull": { "lanes.$.stacks": { "_id": stackId } }
			}, {
				safe: true
			})
		} else {
			const { laneIndex, stackIndex } = await getStackData(boardId, laneId, stackId)
			const toSet = `lanes.${laneIndex}.stacks.${stackIndex}.messages`
			await Board.updateOne(queryStack(boardId, laneId, stackId),
				{ "$pull": { [`${toSet}`]: { "_id": messageId } } },
				{ safe: true }
			)
		}
	}
	/**
	 * Renders the dashboard for a user.
	 * Dashboard includes all templates and boards that are created by the user.
	 */
	app.get('/dashboard', secure, async (req, res) => {
		const userId = req.user.id
		try {
			const templates = await Template.find({ createrId: userId })
			const boards = await Board.find({ createrId: userId })
			res.render('dashboard', {
				templates: templates.length > 0 
					? templates.map(doc => doc.toObject()) 
					: undefined,
				boards: boards.length > 0
					? boards
						.map(doc => doc.toObject())
						.map(obj => Object.assign(obj, { date: formatDate(obj.date) }))
					: undefined
			})
		} catch (err) {
			console.error(err)
		}
	})
	/**
	 * Renders a template by id as json if the user that requests it is the 
	 * creater of that templarte.
	 */
	app.get('/template', secure, async (req, res) => {
		const userId = req.user.id
		try {
			const template = await Template.find({ 
				_id: req.query.id,
				createrId: userId
			})
			res.json(template[0].toObject())
		} catch (err) {
			console.error(err)
		}
	})
	/**
	 * Saves a template a in the data base
	 */
	app.post('/template-create', secure, async (req, res) => {
		const userId = req.user.id
		const template = new Template({
			name: req.body.name,
			createrId: userId,
			lanes: req.body.lanes
		})
		try {
			const result = await template.save()
			res.json(result.toObject())
		} catch (err) {
			res.status(400).json({ message: "Validation Error" })
			console.error(err)
		}
	})
	/**
	 * Removes a template from the database if the user that sends the 
	 * request is the creater of the template.
	 */
	app.post('/template-delete', secure, async (req, res) => {
		const userId = req.user.id
		const boardId = req.body.id
		try {
			await Template.deleteOne({ _id: boardId, createrId: userId })
			res.redirect('/dashboard')
		} catch (err) {
			console.error(err)
		}
	})
	/**
	 * Updates a template if the user that sends the
	 * request is the creater of the template.
	 */
	app.post('/template-update', secure, async (req, res) => {
		const userId = req.user.id
		const templateId = req.body.id
		try {
			await Template.updateOne({ _id: templateId, createrId: userId }, req.body)
			const result = await Template.findById(templateId)
			res.json(result)
		} catch (err) {
			console.error(err)
		}
	})
	/**
	 * Creates a board based on a template id
	 */
	app.post('/board-create', secure, async (req, res) => {
		const userId = req.user.id
		const templateId = req.body['template-id']
		try {
			const template = await Template.findOne({ _id: templateId, createrId: userId })
			if (!template) {
				res.render('dashboard', {
					message: "Cannot find Template",
					messageClass: "alert-danger"
				})
			}
			const board = await new Board({
				createrId: userId,
				name: template.name,
				lanes: template.lanes.map(lane => {
					return {
						heading: lane.heading.toString()
					}
				})
			}).save()
			res.redirect('/admin/retro#' + board._id)
		} catch (err) {
			console.error(err)
		}
	})
	/**
	 * Removes a board from the database if the user that sends the
	 * request is the creater of the board.
	 */
	app.post('/board-delete', secure, async (req, res) => {
		const userId = req.user.id
		const boardId = req.body.id
		try {
			await Board.deleteOne({ _id: boardId, createrId: userId })
			res.redirect('/dashboard')
		} catch (err) {
			console.error(err)
		}
	})
	/**
	 * Renders a board by id as json.
	 */
	app.get('/board', async (req, res) => {
		const boardId = req.query['board-id']
		try {
			const board = await Board.findById(boardId)
			res.json(board.toObject())
		} catch (err) {
			console.error(err)
			res.sendStatus(500)
		}
	})
	/**
	 * Renders public retro boards.
	 */
	app.get('/public/retro', async (req, res) => {
		if (!req.cookies[SESSION_ID]) {
			const sessionId = genToken()
			res.cookie(SESSION_ID, sessionId)
		}
		res.render('public-retro')
	})
	/**
	 * Renders admin retro boards.
	 */
	app.get('/admin/retro', secure, async (req, res) => {
		if (!req.cookies[SESSION_ID]) {
			const sessionId = genToken()
			res.cookie(SESSION_ID, sessionId)
		}
		res.render('admin-retro')
	})
	/**
	 * Renders the board-builder app.
	 */
	app.get('/template-create', secure, (req, res) => {
		res.render('board-builder')
	})
	/**
	 * Renders the landing page.
	 */
	app.get('/', (_, res) => res.render('home'))
	
	/**
	 * Socket Connection
	 */
	io.on('connection', (socket) => {
		if (!socket.boardId) {
			return socket.send('error', { message: 'Board: Not Found' })
		}
		socket.join(socket.boardId)
		/**
		 * Adds an messagestack with one empty meesage to a board.
		 * data.boardId: the id of the board where the message belongs to.
		 * data.laneId: the id of the lane on the board where the message is placed.
		 */
		socket.on('create-message', async (data) => {
			const boardId = data.boardId
			const laneId = data.laneId
			try {
				const board = await createMessage(socket.sessionId, boardId ,laneId)
				io.to(socket.boardId).emit('update-board', board)
			} catch (err) {
				console.error(err)
				socket.send('error', { message: 'Something went wrong' })
			}
		})
		/**
		 * Removes a message from a board
		 * data.boardId: the id of the board where the message belongs to.
		 * data.laneId: the id of the land where the message is placed.
		 * data.messageId: the id of the message that should be removed.
		 */
		socket.on('delete-message', async (data) => {
			const boardId = data.boardId
			const laneId = data.laneId
			const stackId = data.stackId
			const messageId = data.messageId
			try {
				await deleteMessage(boardId, laneId, stackId, messageId)
				const board = await Board.findById(boardId)
				if (!board) socket.send('error', { message: 'Board: Not Found' })
				io.to(socket.boardId).emit('update-board', board)
			} catch (err) {
				console.error(err)
				socket.send('error', { message: 'Something went wrong' })
			}
		})
		/**
		 * Updates the text of a message.
		 * data.boardId: the id of the board where the message belongs to.
		 * data.laneId: the id of the land where the message is placed.
		 * data.messageId: the id of the message that should be updated.
		 * data.text: the new text of the message.
		 */
		socket.on('update-message-text', async (data) => {
			const boardId = data.boardId
			const laneId = data.laneId
			const stackId = data.stackId
			const messageId = data.messageId
			const text = data.text
			try {
				const { laneIndex, stackIndex, messageIndex } = await getMessageData(boardId, laneId, stackId, messageId)
				const toSet = `lanes.${laneIndex}.stacks.${stackIndex}.messages.${messageIndex}.text`
				await Board.updateOne(queryMessage(boardId, laneId, stackId, messageId), { 
					"$set": { [`${toSet}`]: text } 
				}, { safe: true })
				const board = await Board.findById(boardId)
				if (!board) socket.send('error', { message: 'Board: Not Found' })
				io.to(socket.boardId).emit('update-board', board)
			} catch (err) {
				console.error(err)
				socket.send('error', { message: 'Something went wrong' })
			}
		})
		/**
		 * Increases the upvotes of a message by one.
		 * data.boardId: the id of the board where the message belongs to.
		 * data.laneId: the id of the land where the message is placed.
		 * data.messageId: the id of the message that should be updated.
		 */
		socket.on('update-message-upvote', async (data) => {
			const boardId = data.boardId
			const laneId = data.laneId
			const stackId = data.stackId
			const messageId = data.messageId
			try {
				const { laneIndex, stackIndex, messageIndex } = await getMessageData(boardId, laneId, stackId, messageId)
				const toSet = `lanes.${laneIndex}.stacks.${stackIndex}.messages.${messageIndex}.upvotes`
				await Board.updateOne(queryMessage(boardId, laneId, stackId, messageId), { 
					"$inc": { [`${toSet}`]: 1 } 
				}, { safe: true })
				const board = await Board.findById(boardId)
				if (!board) socket.send('error', { message: 'Board: Not Found' })
				io.to(socket.boardId).emit('update-board', board)
			} catch (err) {
				console.error(err)
				socket.send('error', { message: 'Something went wrong' })
			}
		})
		/**
		 * Adds one message to another message stack.
		 * data.boardId: the id of the board where the message belongs to.
		 * data.childLaneId: the id of the land where the message was before it was moved.
		 * data.childStackId: the id of the message stack where the message was before it was moved.
		 * data.childMessageId: the id of the moved message.
		 * data.parentLaneId: the id of the lane where the new messagesstack of the message is.
		 * data.parentStackId: the id of the stack where the message should be placed
		 */
		socket.on('merge-message', async (data) => {
			const boardId = data.boardId
			const childLaneId = data.childLaneId
			const childStackId = data.childStackId
			const childMessageId = data.childMessageId
			const parentLaneId = data.parentLaneId
			const parentStackId = data.parentStackId
			try {
				// get child data
				const { message } = await getMessageData(boardId, childLaneId, childStackId, childMessageId)
				const { laneIndex, stackIndex } = await getStackData(boardId, parentLaneId, parentStackId)
				const toSet = `lanes.${laneIndex}.stacks.${stackIndex}.messages`
				// push child data in patent stack
				await Board.updateOne(queryStack(boardId, parentLaneId, parentStackId), {
					"$push": { [`${toSet}`]: message }
				}, {
					safe: true
				})
				await deleteMessage(boardId, childLaneId, childStackId, childMessageId)
				// return new board state
				const board = await Board.findById(boardId)
				if (!board) socket.send('error', { message: 'Board: Not Found' })
				io.to(socket.boardId).emit('update-board', board)
			} catch (err) {
				console.error(err)
				socket.send('error', { message: 'Something went wrong' })
			}
		})
		/**
		 * Removes a message from a message stack and adds it to a lane.
		 * data.boardId: the id of the board where the message belongs to.
		 * data.childLaneId: the id of the land where the message was before it was moved.
		 * data.childStackId: the id of the message stack where the message was before it was moved.
		 * data.childMessageId: the id of the moved message.
		 * data.parentLaneId: the id of the lane where the message should be moved into.
		 */
		socket.on('split-message-stack', async (data) => {
			const boardId = data.boardId
			const childLaneId = data.childLaneId
			const childStackId = data.childStackId
			const childMessageId = data.childMessageId
			const parentLaneId = data.parentLaneId
			try {
				// get child message
				const { message } = await getMessageData(boardId, childLaneId, childStackId, childMessageId)
				// add child message to parent lane
				await createMessage(socket.sessionId, boardId, parentLaneId, message)
				// remove child message from child stack
				await deleteMessage(boardId, childLaneId, childStackId, childMessageId)
				const board = await Board.findById(boardId)
				io.to(socket.boardId).emit('update-board', board)
			} catch (err) {
				console.error(err)
				socket.send('error', { message: 'Something went wrong' })
			}
		})
		/**
		 * Creates an action item
		 * data.boardId: the id of the board where the action item belongs to.
		 * data.laneId: the lane where the message stack of the action item is.
		 * data.stackId: the message stack of the action item.
		 */
		socket.on('create-action-item', async (data) => {
			const boardId = data.boardId
			const laneId = data.laneId
			const stackId = data.stackId
			try {
				const { laneIndex, stackIndex } = await getStackData(boardId, laneId, stackId)
				const toSet = `lanes.${laneIndex}.stacks.${stackIndex}.actions`
				const action = new Action({
					boardId: boardId,
					text: ''
				})
				await Board.updateOne(queryStack(boardId, laneId, stackId), {
					"$push": { [`${toSet}`]: action } 
				}, { 
					safe: true 
				})
				const board = await Board.findById(boardId)
				io.to(socket.boardId).emit('update-board', board)
			} catch (err) {
				console.error(err)
				socket.send('error', { message: 'Something went wrong' })
			}
		})
		/**
		 * Deletes an action item
		 * data.boardId: the id of the board where the action item belongs to.
		 * data.laneId: the lane where the message stack of the action item is.
		 * data.stackId: the message stack of the action item.
		 * data.actionId: the id of the action item to remove.
		 */
		socket.on('delete-action-item', async (data) => {
			const boardId = data.boardId
			const laneId = data.laneId
			const stackId = data.stackId
			const actionId = data.actionId
			try {
				const { laneIndex, stackIndex } = await getStackData(boardId, laneId, stackId)
				const toSet = `lanes.${laneIndex}.stacks.${stackIndex}.actions`
				await Board.updateOne(queryStack(boardId, laneId, stackId), {
					"$pull": { [`${toSet}`]: { "_id": actionId } },
				}, {
					safe: true
				})
				const board = await Board.findById(boardId)
				io.to(socket.boardId).emit('update-board', board)
			} catch (err) {
				console.error(err)
				socket.send('error', { message: 'Something went wrong' })
			}
		})
		/**
		 * Updates an action items text.
		 * data.boardId: the id of the board where the action item belongs to.
		 * data.laneId: the id of the lane where the message stack of the action item is.
		 * data.stackId: the id of the message stack of the action item.
		 * data.actionId: the id of the action item.
		 * data.text: the new text of the action item.
		 */
		socket.on('update-action-text', async (data) => {
			const boardId = data.boardId
			const laneId = data.laneId
			const stackId = data.stackId
			const actionId = data.messageId
			const text = data.text
			try {
				const { laneIndex, stackIndex, actionIndex } = await getActionData(boardId, laneId, stackId, actionId)
				const toSet = `lanes.${laneIndex}.stacks.${stackIndex}.actions.${actionIndex}.text`
				await Board.updateOne(queryActionText(boardId, laneId, stackId, actionId), {
					"$set": { [`${toSet}`]: text },
				}, {
					safe: true
				})
				const board = await Board.findById(boardId)
				io.to(socket.boardId).emit('update-board', board)
			} catch (err) {
				console.error(err)
				socket.send('error', { message: 'Something went wrong' })
			}
		})
	})
})
.catch(err => console.error(err))

http.listen(3000, () => console.log('Server running ...'))


