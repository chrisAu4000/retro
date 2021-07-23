const path = require('path')
describe('public board', () => {
	describe('create new message', () => {
		before(() => {
			cy.task('removeBoards')
			cy.task('emptyBoard')
		})
		it('finds the board', () => {
			cy.visit('/public/retro#60f6802390d0de625739acfb')
		})
		it('creates a message', () => {
			cy.get('.add-message')
				.first()
				.trigger('click')
			cy.get('.message-stack')
				.should('has.length', 1)
			cy.get('.message')
				.should('has.length', 1)
		})
		it('writes a message', () => {
			cy.get('.message .form-control')
				.type('test message')
				.should('has.value', 'test message')
		})
		it('upvotes a message', () => {
			cy.get('.message .upvote')
				.trigger('click')
				.should('have.text', '1')
		})
		it('removes message', () => {
			cy.get('.message .delete-message')
				.trigger('click')
			cy.get('.message-stack')
				.should('has.length', 0)
			cy.get('.message')
				.should('has.length', 0)
		})
	})
})