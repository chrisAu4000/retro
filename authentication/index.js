const express = require('express')
const bodyParser = require('body-parser')
const cookieParser = require('cookie-parser')
const exphbs = require('express-handlebars')
const mongoose = require('mongoose')
const routes = require('./routes')

const app = express()
app.use(bodyParser.urlencoded({ exteneded: false }))
app.use(cookieParser());
app.engine('hbs', exphbs({ extname: '.hbs' }));
app.set('view engine', 'hbs');
const mongoOpts = { 
	useNewUrlParser: true,
	useUnifiedTopology: true 
}
mongoose.connect('mongodb://mongo:27017/users', mongoOpts)
	.then((connection) => {
		routes(app, connection)
		console.log('Authentication running ...')
	})
	.catch(err => console.error(err))

app.listen(3001)