const path = require('path')
const crypto = require('crypto')
const Http = require('http')
const express = require('express')
const bodyParser = require('body-parser')
const mongoose = require('mongoose')
const exphbs = require('express-handlebars')
const cookieParser = require('cookie-parser')
// const session = require('express-session')
const SocketIo = require('socket.io')
const redis = require('./redis-client')
const templateSchema = require('./models/Template')
const boardSchema = require('./models/Board')
const messageSchema = require('./models/Message')

const app = express()
const http = Http.createServer(app);
const io = SocketIo(http)

const genToken = () => crypto.randomBytes(30).toString('hex')
const formatDate = (date) => date.toISOString().replace(/T/, ' ').replace(/\..+/, '')

const SESSION_ID = 'SessionId'

app.engine('hbs', exphbs({ extname: '.hbs' }));
app.set('view engine', 'hbs');
app.set('trust proxy', 1)
app.use(bodyParser.urlencoded({ extended: false }))
app.use(bodyParser.json())
app.use(cookieParser())
app.use(express.static(path.join(__dirname, 'public')))
// app.use(session({ secret: 'secret session' }))
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

const secure = (req, res, next) => {
	if (req.user) {
		next()
	} else {
		res.redirect('/auth/login')
	}
}

const socketSecure = (socket, next) => {
	if (req.user) {
		next()
	} else {
		next(new Error('invalid user'))
	}
}

mongoose.connect('mongodb://mongo:27017/retro-board', { useNewUrlParser: true })
	.then((connection) => {
		const Template = connection.model('Template', templateSchema)
		const Board = connection.model('Board', boardSchema)
		const Message = connection.model('Message', messageSchema)

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
						? boards.map(doc => doc.toObject()).map(obj => Object.assign(obj, { date: formatDate(obj.date) }))
						: undefined
				})
			} catch (err) {
				console.error(err)
			}
		})
		
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
				console.error(err)
			}
		})

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

		app.get('/public/retro', async (req, res) => {
			if (!req.cookies[SESSION_ID]) {
				const sessionId = genToken()
				res.cookie(SESSION_ID, sessionId)
			}
			res.render('public-retro')
		})

		app.get('/admin/retro', secure, async (req, res) => {
			if (!req.cookies[SESSION_ID]) {
				const sessionId = genToken()
				res.cookie(SESSION_ID, sessionId)
			}
			res.render('admin-retro')
		})

		app.get('/template-create', secure, (req, res) => {
			res.render('board-builder')
		})

		app.get('/', (_, res) => res.render('home'))
		
		/**
		 * Socket Connection
		 */
		io.on('connection', (socket) => {
			if (!socket.boardId) {
				return socket.send('error', { message: 'Board: Not Found' })
			}
			socket.join(socket.boardId)

			socket.on('create-message', async (data) => {
				const boardId = data.boardId
				const laneId = data.laneId
				try {
					const board = await Board.findById(boardId)
					if (!board) return socket.send('error', { message: 'Board: Not Found' })
					const lane = await board.lanes.filter(lane => lane.id === laneId)[0]
					if (!lane) return socket.send('error', { message: 'Lane: Not Found' })
					const message = new Message({
						createrId: socket.sessionId,
						boardId: boardId,
						text: '',
						upvotes: 0,
						type: 'Item'
					})
					lane.messages.push(message)
					await board.save()
					io.to(socket.boardId).emit('update-board', board)
				} catch (err) {
					console.error(err)
					socket.send('error', { message: 'Something went wrong' })
				}
			})

			socket.on('delete-message', async (data) => {
				const boardId = data.boardId
				const laneId = data.laneId
				const messageId = data.messageId
				try {
					await Board.updateOne(
						{ 
							"_id": boardId, 
							"lanes._id": laneId
						}, {
							"$pull": { "lanes.$.messages": { "_id": messageId } }
						}, { 
							safe: true 
						})
					const board = await Board.findById(boardId)
					if (!board) socket.send('error', { message: 'Board: Not Found' })
					io.to(socket.boardId).emit('update-board', board)
				} catch (err) {
					console.error(err)
					socket.send('error', { message: 'Something went wrong' })
				}
			})

			socket.on('update-message-text', async (data) => {
				const boardId = data.boardId
				const laneId = data.laneId
				const messageId = data.messageId
				const text = data.text
				try {
					const lanesDoc = await Board.findOne({_id: boardId}, { lanes: 1 })
					await lanesDoc.lanes.map(async (lane, laneI) => {
						if (lane._id.toString() !== laneId) {
							return
						}
						lane.messages.map(async (message, messageI) => {
							if (message._id.toString() !== messageId) {
								return
							}
							const toSet = 'lanes.'+laneI+'.messages.'+messageI+'.text'
							await Board.updateOne(
								{
									"_id": boardId,
									"lanes": {
										"$elemMatch": {
											"_id": laneId,
											"messages": {
												"$elemMatch": {
													"_id": messageId
												}
											}
										}
									}
								},
								{ "$set": { [`${toSet}`]: text } },
								{ safe: true }
							)
							const board = await Board.findById(boardId)
							if (!board) socket.send('error', { message: 'Board: Not Found' })
							io.to(socket.boardId).emit('update-board', board)
						})
					})
				} catch (err) {
					console.error(err)
					socket.send('error', { message: 'Something went wrong' })
				}
			})
			socket.on('update-message-upvote', async (data) => {
				const boardId = data.boardId
				const laneId = data.laneId
				const messageId = data.messageId
				try {
					const lanesDoc = await Board.findOne({ _id: boardId }, { lanes: 1 })
					await lanesDoc.lanes.map(async (lane, laneI) => {
						if (lane._id.toString() !== laneId) {
							return
						}
						lane.messages.map(async (message, messageI) => {
							if (message._id.toString() !== messageId) {
								return
							}
							const toSet = 'lanes.' + laneI + '.messages.' + messageI + '.upvotes'
							await Board.updateOne(
								{
									"_id": boardId,
									"lanes": {
										"$elemMatch": {
											"_id": laneId,
											"messages": {
												"$elemMatch": {
													"_id": messageId
												}
											}
										}
									}
								},
								{ "$inc": { [`${toSet}`]: 1 } },
								{ safe: true }
							)
							const board = await Board.findById(boardId)
							if (!board) socket.send('error', { message: 'Board: Not Found' })
							io.to(socket.boardId).emit('update-board', board)
						})
					})
				} catch (err) {
					console.error(err)
					socket.send('error', { message: 'Something went wrong' })
				}
			})
		})
		
		console.log('MongoDB Connected')
	})
	.catch(err => console.error(err))

http.listen(3000, () => console.log('Server running ...'))