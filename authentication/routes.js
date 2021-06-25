const crypto = require('crypto')

const userSchema = require('./model/User')
const redis = require('./redis-client.js')
const AUTH_TOKEN = 'AuthToken'
/**
 * Generates a hash from the input.
 */
const sha256 = (input) => crypto.createHash('sha256').update(input).digest('base64')
/**
 * Generates a random token. Format is hex
 */
const genToken = () => crypto.randomBytes(30).toString('hex')
/**
 * Renders a given template with error message
 */
const renderDanger = (res, template) => (message) => res.render(template, { message, messageClass: 'alert-danger' })
/**
 * Writes a user into the data base.
 * Error if:
 * 	password and password confirmation doesn't match
 * 	user already exists
 * 	user can't be saved
 */
const register = (User) => async (req, res) => {
	const { firstName, lastName, email, password, confirmPassword } = req.body
	const renderDangerRegister = renderDanger(res, 'register')
	if (password !== confirmPassword) {
		return renderDangerRegister('Password does not match')
	}
	const userExists = await User.exists({ email: email })
	if (userExists) {
		return renderDangerRegister('User is already registered')
	}
	const hashedPassword = sha256(password)
	const user = new User({
		firstName: firstName,
		lastName: lastName,
		email: email,
		password: hashedPassword
	})
	try {
		await user.save()
	} catch (error) {
		console.log(error)
		return renderDangerRegister('Something went wrong')
	}
	return res.render('login', {
		message: 'Registration complete. Please login to continue.',
		messageClass: 'alert-success'
	})
}
/**
 * Logs in a user by setting a auth token in on cookie.
 * Error if:
 * 	User not found.
 * 	Password doesn't match
 * 	Redis cannot save token
 */
const login = (User) => async (req, res) => {
	const renderDangerLogin = renderDanger(res, 'login')
	const { email, password } = req.body
	const redirect = req.query.redirect || 'dashboard'
	const userExists = await User.exists({ email: email })
	if (!userExists) {
		return renderDangerLogin('User not found. Please register first.')
	}
	const user = await User.findOne({ email: email })
	if (user.password !== sha256(password)) {
		return renderDangerLogin('Wrong password.')
	}
	const token = genToken()
	const props = { 
		id: user._id, 
		fistName: user.firstName, 
		lastName: user.lastName, 
		role: user.role
	}
	try {
		await redis.set(token, JSON.stringify(props))
		res.cookie(AUTH_TOKEN, token)
		res.redirect('/' + redirect)
	} catch (err) {
		console.error(err)
		return renderDangerLogin('Something went wrong')
	}
}
/**
 * Removes the auth token from cookie.
 */
const logout = (_, res) => {
	res.cookie(AUTH_TOKEN, null)
	res.render('login')
}
/**
 * Assigns routes to there handlers.
 */
module.exports = (app, connection) => {
	const User = connection.model('User', userSchema)
	app.get('/', (_, res) => res.render('home'))
	app.get('/register', (_, res) => res.render('register'))
	app.get('/login', (_, res) => res.render('login'))
	app.get('/logout', logout)
	app.post('/register', register(User))
	app.post('/login', login(User))
}