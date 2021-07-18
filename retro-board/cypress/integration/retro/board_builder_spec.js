describe('example to-do app', () => {
	beforeEach(() => {
	// 	cy.exec('npm run dev:server')
	 	cy.exec('mongo retro --eval "db.dropDatabase()"')
	})
	describe('Landing page', () => {
		it('successfully loads', () => {
			cy.visit('/')
		})
	})
	describe('Dashboard', () => {
		it('successfully loads', () => {
			cy.visit('/dashboard')
		})
	})
	describe('Board builder', () => {
		it('successfully loads', () => {
			cy.visit('/template-create')
		})
		it('displays no lanes by default', () => {
			cy.get('.lane').should('not.exist')
		})
		it('save button is disabled until at least two lanes are added', () => {
			cy.get('.save-template')
				.should('have.length', 1)
				.should('be.disabled')
			cy.get('.add-lane')
				.trigger('click')
				.trigger('click')
			cy.get('.lane')
				.should('have.length', 2)
			cy.get('.save-template')
				.should('not.be.disabled')
		})
		it('remove lane', () => {
			cy.get('.add-lane')
				.trigger('click')
			cy.get('.lane')
				.should('have.length', 3)
			cy.get('.delete-lane')
				.first()
				.trigger('click')
			cy.get('.lane')
				.should('have.length', 2)
		})
		it('validate lane names should not be empty', () => {
			cy.get('.save-template')
				.click()
			cy.get('.alert')
				.should('have.length', 1)
			// should show error lanes need names
		})
		it('saves template', () => {
			cy.get('.template-name')
				.type('test-template')
			cy.get('.lane')
				.first()
				.type('test 1')
			cy.get('.lane')
				.last()
				.type('test 1')
			cy.get('.save-template')
				.click()
			cy.get('.template').should('have.length', 1)
		})
	})
})