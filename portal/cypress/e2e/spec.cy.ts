import "cypress/support/commands";
import { ActionTypes } from "../../src/store";
import { SnackbarStyle } from "../../src/store/modules/snackbar";
import { getPartnerCustomizationWithDefault, isCustomisationEnabled, PartnerCustomization } from "../../src/views/shared/partners";
import { apiUrl } from "../support/commands";

//import {FKApi} from '../../src/api';

const stationPageUrl = "/station/1";

describe("Station Page", () => {

    beforeEach(() => {
        cy.login();
        cy.addStation();
        cy.get("@stationPageUrl").then((stationPageUrl) => {
            cy.wrap(stationPageUrl).as("stationPageUrl");
            Cypress.env("stationPageUrl", stationPageUrl);
        });
    });

    it("should create a new station and navigate to its page", () => {
        cy.visit("@stationPageUrl");
    });

    it("should display save button if user is authenticated", () => {
        cy.login();
        cy.visit(stationPageUrl);
        cy.get('[data-cy="saveNotes"]');
    });

    it("should not display save button if user is not authenticated", () => {
        cy.login();
        cy.visit(stationPageUrl);
        cy.get('[data-cy="saveNotes"]').should("not.exist");
    });

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
        cy.intercept("PATCH", "/stations/1/notes", { fixture: "success.json" }).as("submitForm");

        // Click submit button
        cy.get('.buttons button[type="submit"]').click();

        // Assert that API call was successful
        cy.wait("@submitForm").its("response.statusCode").should("eq", 200);
    });

    it("go back to stations dashboard", () => {
        cy.login();
        cy.visit(stationPageUrl);
        cy.get('[data-cy="backBtn"]').click();
        cy.url().should("eq", Cypress.config("baseUrl") + "/dashboard/stations/1");
    });

    it("shows Field Notes Section", () => {
        cy.login();
        cy.visit(stationPageUrl);
        cy.get('[data-cy="fieldNotes"]');
    });

    it("can edit station description", () => {
        const partnerCustomization = window.location.hostname.indexOf("floodnet.") >= 0;

        if (!partnerCustomization) {
        }
    });*/
});
