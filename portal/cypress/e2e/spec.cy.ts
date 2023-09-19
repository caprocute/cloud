import 'cypress/support/commands';

describe('Station Page', () => {
    it('successfully loads w/ token', () => {
        cy.login();
        cy.visit('/station/1')
    })
})
