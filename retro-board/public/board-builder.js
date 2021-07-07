/*
 * ATTENTION: The "eval" devtool has been used (maybe by default in mode: "development").
 * This devtool is neither made for production nor for readable output files.
 * It uses "eval()" calls to create a separate source file in the browser devtools.
 * If you are trying to read the output file, select a different devtool (https://webpack.js.org/configuration/devtool/)
 * or disable the default devtool with "devtool: false".
 * If you are looking for production-ready output files, see mode: "production" (https://webpack.js.org/configuration/mode/).
 */
/******/ (() => { // webpackBootstrap
/******/ 	var __webpack_modules__ = ({

/***/ "./elm-apps/board-builder/index.js":
/*!*****************************************!*\
  !*** ./elm-apps/board-builder/index.js ***!
  \*****************************************/
/***/ ((__unused_webpack_module, __unused_webpack_exports, __webpack_require__) => {

eval("var Elm = __webpack_require__(/*! ./src/Main.elm */ \"./elm-apps/board-builder/src/Main.elm\").Elm;\nvar node = document.getElementById(\"elm\")\nvar app = Elm.Main.init({ node: node, flags: window.location.hash.replace('#', '') })\nconst init = () => {\n\tif (app.ports) {\n\t\tapp.ports.dragstart && app.ports.dragstart.subscribe(function (event) {\n\t\t\tevent.dataTransfer.setData('text', '');\n\t\t});\n\t\tvar mySockets = {};\n\t\tapp.ports.sendSocketCommand && app.ports.sendSocketCommand.subscribe(function (wat) {\n\t\t\tconsole.log(\"ssc: \" + JSON.stringify(wat, null, 4));\n\t\t\tif (wat.cmd == \"connect\") {\n\t\t\t\t// console.log(\"connecting!\");\n\t\t\t\tlet socket = new WebSocket(wat.address);\n\t\t\t\tsocket.onmessage = function (event) {\n\t\t\t\t\t// console.log( \"onmessage: \" +  JSON.stringify(event.data, null, 4));\n\t\t\t\t\tapp.ports.receiveSocketMsg.send({\n\t\t\t\t\t\tname: wat.name\n\t\t\t\t\t\t, msg: \"data\"\n\t\t\t\t\t\t, data: event.data\n\t\t\t\t\t});\n\t\t\t\t}\n\t\t\t\tmySockets[wat.name] = socket;\n\t\t\t}\n\t\t\telse if (wat.cmd == \"send\") {\n\t\t\t\t// console.log(\"sending to socket: \" + wat.name );\n\t\t\t\tmySockets[wat.name].send(wat.content);\n\t\t\t}\n\t\t\telse if (wat.cmd == \"close\") {\n\t\t\t\t// console.log(\"closing socket: \" + wat.name);\n\t\t\t\tmySockets[wat.name].close();\n\t\t\t\tdelete mySockets[wat.name];\n\t\t\t}\n\t\t});\n\t}\n}\ninit();\n\n\n//# sourceURL=webpack://retro-board/./elm-apps/board-builder/index.js?");

/***/ }),

/***/ "./elm-apps/board-builder/src/Main.elm":
/*!*********************************************!*\
  !*** ./elm-apps/board-builder/src/Main.elm ***!
  \*********************************************/
/***/ (() => {

eval("throw new Error(\"Module build failed (from ./node_modules/elm-webpack-loader/index.js):\\nCompiler process exited with error Compilation failed\");\n\n//# sourceURL=webpack://retro-board/./elm-apps/board-builder/src/Main.elm?");

/***/ })

/******/ 	});
/************************************************************************/
/******/ 	// The module cache
/******/ 	var __webpack_module_cache__ = {};
/******/ 	
/******/ 	// The require function
/******/ 	function __webpack_require__(moduleId) {
/******/ 		// Check if module is in cache
/******/ 		if(__webpack_module_cache__[moduleId]) {
/******/ 			return __webpack_module_cache__[moduleId].exports;
/******/ 		}
/******/ 		// Create a new module (and put it into the cache)
/******/ 		var module = __webpack_module_cache__[moduleId] = {
/******/ 			// no module.id needed
/******/ 			// no module.loaded needed
/******/ 			exports: {}
/******/ 		};
/******/ 	
/******/ 		// Execute the module function
/******/ 		__webpack_modules__[moduleId](module, module.exports, __webpack_require__);
/******/ 	
/******/ 		// Return the exports of the module
/******/ 		return module.exports;
/******/ 	}
/******/ 	
/************************************************************************/
/******/ 	
/******/ 	// startup
/******/ 	// Load entry module and return exports
/******/ 	// This entry module can't be inlined because the eval devtool is used.
/******/ 	var __webpack_exports__ = __webpack_require__("./elm-apps/board-builder/index.js");
/******/ 	
/******/ })()
;