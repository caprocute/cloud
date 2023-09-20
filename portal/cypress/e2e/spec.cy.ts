import 'cypress/support/commands';

describe('Station Page', () => {
    it('successfully loads w/ token', () => {
        cy.login();
        cy.visit('/station/1')
    })

    it('Shows Notes Form', () => {
        cy.login();
        cy.visit('/station/1');
        cy.get('[test-id="notesForm"]');
    })
})
