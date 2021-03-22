const Elm = require('./src/Main.elm').Elm;
const io = require('socket.io-client')
const socket = io(location.origin + '/', {
	autoConnect: false
})
const getCookie = (name) => {
	const value = `; ${document.cookie}`;
	const parts = value.split(`; ${name}=`);
	if (parts.length === 2) return parts.pop().split(';').shift();
}

const init = () => {
	const boardId = location.hash.replace('#', '')
	const sessionId = getCookie('SessionId')
	socket.auth = { boardId: boardId, sessionId: sessionId }

	socket.on("connect_error", (err) => {
		if (err.message === "invalid user") {
			location.hash = ''
			location.href = '/auth/login'
		}
	})
	let app = undefined
	socket.on('connect', () => {
		
		if (app) return
		const node = document.getElementById("elm")
		app = Elm.Main.init({ node: node, flags: { 
			href: window.location.href,
			user: sessionId
		}})

		if (!app.ports) return;

		app.ports.sendSocketMessage && app.ports.sendSocketMessage.subscribe((event) => {
			socket.emit(event.action, event.content)
		})
	})

	socket.on('update-board', data => {
		app.ports.receiveSocketMessage.send(data);
	})

	socket.on('error', (data) => {
		console.error(data)
	})

	socket.connect();
}
init();
