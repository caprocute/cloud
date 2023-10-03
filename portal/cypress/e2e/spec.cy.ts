import "cypress/support/commands";
import {ActionTypes} from "../../src/store";
import {SnackbarStyle} from "../../src/store/modules/snackbar";

const stationPageUrl = "/station/1";

describe("Station Page", () => {
    /* it("successfully loads w/ token", () => {
        cy.login();
        cy.visit(stationPageUrl);
    });

    it(shows station details form", () => {
        cy.login();
        cy.visit(stationPageUrl);
        cy.get('[data-cy="notesForm"]');
    });

    it("should display save button if user is authenticated", () => {
        cy.login();
        cy.visit(stationPageUrl);
        cy.get('[data-cy="saveNotes"]');
    });*/

    /*    it("should not display save button if user is not authenticated", () => {
        cy.login();
        cy.visit(stationPageUrl);
        cy.get('[data-cy="saveNotes"]').should("not.exist");
    });*/

   /* it("should successfully save the form when valid data is entered", () => {
        // Assuming that there are commands to log in a user and set up necessary preconditions.
        cy.login();

        cy.wait(2000);

        cy.visit(stationPageUrl);

        cy.get('[data-cy="studyObjectiveBody"]').type("Some text");
        cy.get('[data-cy="sitePurposeBody"]').type("Some text");
        cy.get('[data-cy="siteCriteriaBody"]').type("Some text");
        cy.get('[data-cy="siteDescriptionBody"]').type("Some text");
        cy.get('[data-cy="customKeyBody"]').type("Some text");

        cy.get('[data-cy="editCustomKey"]').click();
        cy.get('[data-cy="customKeyTitle"]').clear().type("Some title");

        // Stub response for API call(s) made during form submission (replace '/api-endpoint' with actual endpoint)
        cy.intercept("PATCH", "/stations/1/notes", {fixture: "success.json"}).as("submitForm");

        // Click submit button
        cy.get('.buttons button[type="submit"]').click();

        // Assert that API call was successful
        cy.wait("@submitForm").its("response.statusCode").should("eq", 200);
    });*/

    it("shows Field Notes Section", () => {
        cy.login();
        cy.visit(stationPageUrl);
        cy.get('[data-cy="fieldNotes"]');
    });
});
