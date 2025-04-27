<template>
    <div class="language-selector">
        <span class="triangle"></span>
        <i class="icon icon-globe"></i>
        <ul class="language-list">
            <li @click="changeLang(Locales.enUS)">{{ $t("languageSelector.english") }}</li>
            <li @click="changeLang(Locales.esEs)">{{ $t("languageSelector.spanish") }}</li>
        </ul>
    </div>
</template>

<script lang="ts">
import Vue from "vue";
import { ActionTypes } from "@/store";
import { updateDocumentTitle } from "@/router";
import moment from "moment";

export enum Locales {
    enUS = "en-US",
    esEs = "es-ES",
}

export default Vue.extend({
    name: "LanguageSelector",
    data() {
        return {
            Locales: Locales,
        };
    },
    methods: {
        changeLang(locale: Locales) {
            this.$i18n.locale = locale;
            localStorage.setItem("locale", locale);
            this.$store.dispatch(ActionTypes.REFRESH_WORKSPACE);
            updateDocumentTitle();
            moment.locale(locale);
            this.$root.$emit("language-changed");
        },
    },
});
</script>

<style scoped lang="scss">
@use "src/scss/mixins";
@use "src/scss/variables";

.language-selector {
    margin-right: 20px;
    margin-top: -3px;
    padding: 10px;
    position: relative;
    height: 100%;
    display: flex;
    align-items: center;
    box-sizing: border-box;

    @include mixins.bp-down(variables.$sm) {
        margin-right: 5px;
    }

    .triangle {
        opacity: 0;
        visibility: hidden;
        bottom: -2px;
    }

    @include mixins.attention() {
        .language-list,
        .triangle {
            visibility: visible;
            opacity: 1;
        }
    }

    &:after {
        content: "";
        background: url("../../assets/icon-chevron-dropdown.svg") no-repeat center center;
        width: 10px;
        height: 10px;
        transition: all 0.33s;
        transform: translateY(-50%);
        cursor: pointer;
        @include mixins.position(absolute, 50% null null calc(100% - 5px));

        @include mixins.bp-down(variables.$lg) {
            right: 0;
        }

        @include mixins.bp-down(variables.$sm) {
            display: none;
        }
    }

    &:hover {
        &:after {
            transform: rotate(180deg) translateY(50%);
        }
    }
}

.language-list {
    position: absolute;
    right: -10px;
    top: 66px;
    box-shadow: 2px 2.3px 4px 1px rgba(0, 0, 0, 0.04);
    border: solid 1px #d8dce0;
    background-color: #fff;
    min-width: 100px;
    opacity: 0;
    visibility: hidden;
    padding-top: 10px;

    @include mixins.bp-down(variables.$xs) {
        top: 55px;
    }

    li {
        padding: 6px 12px;
        text-align: left;
        cursor: pointer;
        transition: background-color 0.5ms;

        &.active,
        &:hover {
            background-color: #f4f5f7;
        }
    }
}

.icon-globe {
    font-size: 16px;
}
</style>
