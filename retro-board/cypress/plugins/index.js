/// <reference types="cypress" />
// ***********************************************************
// This example plugins/index.js can be used to load plugins
//
// You can change the location of this file or turn off loading
// the plugins file with the 'pluginsFile' configuration option.
//
// You can read more here:
// https://on.cypress.io/plugins-guide
// ***********************************************************

// This function is called when a project is opened or re-opened (e.g. due to
// the project's config changing)
const { connect } = require('../../server/mongo-client')
const templateSchema = require('../../server/models/Template')
const boardSchema = require('../../server/models/Board')
const { messageSchema, actionSchema, messageStackSchema } = require('../../server/models/Message')
/**
 * @type {Cypress.PluginConfig}
 */
// eslint-disable-next-line no-unused-vars
module.exports = async (on, config) => {
	// `on` is used to hook into various events Cypress emits
	// `config` is the resolved Cypress config
	const connection = await connect()
	const Template = connection.model('Template', templateSchema)
	const Board = connection.model('Board', boardSchema)
	const Message = connection.model('Message', messageSchema)
	const Action = connection.model('Action', actionSchema)
	const MessageStack = connection.model('MessageStack', messageStackSchema)
	on('task', {
		async removeBoards() {
			return await Board.remove({})
		},
		async emptyBoard() {
			return await new Board({
				"name": "test",
				"_id": "60f6802390d0de625739acfb",
				"createrId": "test-user",
				"lanes": [
					{
						"_id": "60f6802390d0de625739acfc",
						"heading": "test a",
						"stacks": []
					}, {
						"_id": "60f6802390d0de625739acfd",
						"heading": "test b",
						"stacks": []
					}
				]
			}).save()
		}
	})
}
