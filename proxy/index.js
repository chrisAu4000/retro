const express = require('express')
const cookieParser = require('cookie-parser')
const winston = require('winston')
const expressWinston = require('express-winston')
const { createProxyMiddleware } = require('http-proxy-middleware');
// const mongoose = require('mongoose')

const RETRO_BOARD_URL = 'http://retro-board:3000'
const AUTHENTICATION_URL = 'http://authentication:3001'

const app = express()
// app.use(expressWinston.logger({
// 	transports: [
// 		new winston.transports.Console()
// 	],
// 	format: winston.format.combine(
// 		winston.format.colorize(),
// 		winston.format.json()
// 	),
// 	// meta: true, // optional: control whether you want to log the meta data about the request (default to true)
// 	msg: "HTTP {{req.method}} {{req.url}}", // optional: customize the default logging message. E.g. "{{res.statusCode}} {{req.method}} {{res.responseTime}}ms {{req.url}}"
// 	expressFormat: true, // Use the default Express/morgan request formatting. Enabling this will override any msg if true. Will only output colors with colorize set to true
// 	colorize: false, // Color the text and status code, using the Express/morgan color palette (text: gray, status: default green, 3XX cyan, 4XX yellow, 5XX red).
// 	ignoreRoute: function (req, res) { return false; } // optional: allows to skip some log messages based on request and/or response
// }));

app.use(cookieParser())

const retroProxyOptions = {
	target: RETRO_BOARD_URL,
	followRedirects: true,
	pathRewrite: {
		'^/retro': '/', // rewrite path
	}
}
app.use('/retro', createProxyMiddleware(retroProxyOptions))

const authenticationProxyOptions = {
	target: AUTHENTICATION_URL,
	changeOrigin: true,
	followRedirects: true,
	pathRewrite: {
		'^/auth/login': '/login?redirect=retro',
		'^/auth': '/', // rewrite path
	},
	cookieDomainRewrite: {
		'^/auth/login': 'localhost:1337',
		'authentication': 'localhost:1337'
	}
}
app.use('/auth', createProxyMiddleware(authenticationProxyOptions))

app.use((req, res, next) => {
	console.log('pre - cookies: ', req.cookies)
	next()
	console.log('post - cookies: ', req.cookies)
})

app.listen(1337, () => console.log('Server running ...'))