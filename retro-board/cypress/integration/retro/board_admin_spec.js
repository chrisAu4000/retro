Cypress.Commands.add("dragTo", { prevSubject: "element" }, (subject, targetEl) => {
	cy.wrap(subject).trigger("dragstart")
	cy.get(targetEl).trigger("mousemove")
	cy.get(targetEl).trigger("dragend")
});
describe('public board', () => {
	describe('create new message', () => {
		before(() => {
			cy.task('removeBoards')
			cy.task('emptyBoard')
		})
		it('finds the board', () => {
			cy.visit('/admin/retro#60f6802390d0de625739acfb')
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
		it('creates an action item', () => {
			cy.get('.message-stack .create-action-item')
				.trigger('click')
			cy.get('.message-stack .action-items')
				.should('have.length', 1)
		})
		it('writes into an action item', () => {
			cy.get('.action-item .form-control')
				.type('test action')
				.should('has.value', 'test action')
		})
		it('deletes an action item', () => {
			cy.get('.action-item .delete-action')
				.trigger('click')
			cy.get('.action-item')
				.should('have.length', 0)
		})
		// it('drags message to empty lane', () => {
		// 	cy.get('.drop-zone')
		// 		.should('have.length', 2)
		// 	cy.get(".message").dragTo(":nth-child(2) > .drop-zone");
		// 	cy.get(':nth-child(2) > .flex-column > .message-stack > .message-list > .message')
		// 		.should('have.length', 1)
		// })
		// it('merges two messages', () => {})
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