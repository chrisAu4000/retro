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
const node = document.getElementById("elm")
const app = Elm.Main.init({ node: node, flags: window.location.href })
const init = () => {
	const authToken = getCookie('AuthToken')
	const sessionId = getCookie('SessionId')
	const boardId = location.hash.replace('#', '')
	socket.auth = { 
		authToken : authToken, 
		boardId: boardId, 
		sessionId: sessionId 
	}

	socket.on("connect_error", (err) => {
		if (err.message === "invalid user") {
			location.hash = ''
			location.href = '/auth/login'
		}
	})
	
	socket.on('update-board', data => {
		app.ports.receiveSocketMessage.send(data);
	})

	socket.on('error', (data) => {
		console.error(data)
	})

	socket.connect();

	if (!app.ports) return;
	
	app.ports.copyToClipboard && app.ports.copyToClipboard.subscribe(() => {
		document.querySelector('#copy').select()
		document.execCommand('copy')
	})

	app.ports.sendSocketMessage && app.ports.sendSocketMessage.subscribe((event) => {
		socket.emit(event.action, event.content)
	})

	app.ports.dragstart && app.ports.dragstart.subscribe((event) => {
		event.dataTransfer.setData('text', '')
	});

	app.ports.setHeight && app.ports.setHeight.subscribe((event) => {
		document.getElementById(event.id).style.height = event.value + 'px'
	})
}
init();
