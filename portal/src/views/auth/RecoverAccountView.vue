<template>
    <div class="form-container">
        <Logo class="form-header-logo"></Logo>
        <div v-if="!attempted">
            <form class="form" @submit.prevent="save">
                <h1 class="form-title">{{ $t("recover.form.title") }}</h1>
                <div class="form-subtitle">{{ $t("recover.form.subtitle") }}</div>
                <div class="form-group">
                    <TextField v-model="form.email" label="Email" keyboardType="email" />

                    <div class="form-errors" v-if="$v.form.email.$error">
                        <div v-if="!$v.form.email.required">{{ $t("recover.form.email.required") }}</div>
                        <div v-if="!$v.form.email.email">{{ $t("recover.form.email.valid") }}</div>
                    </div>
                </div>
                <button class="form-submit" type="submit">{{ $t("recover.form.button") }}</button>
                <div>
                    <router-link :to="{ name: 'login' }" class="form-link">{{ $t("recover.form.backButton") }}</router-link>
                </div>
            </form>
        </div>
        <div v-if="attempted" class="form success">
            <div v-if="!resending">
                <img alt="Success" src="@/assets/icon-success.svg" width="57px" class="form-header-icon" />
                <h1 class="form-title">{{ $t("recover.sentTitle") }}</h1>
                <div class="form-subtitle">{{ $t("recover.sentSubtitle") }}</div>
                <button class="form-submit" v-on:click="resend">{{ $t('recover.form.created.resend') }}</button>
                <router-link :to="{ name: 'login' }" class="form-link">{{ $t("recover.form.backButton") }}</router-link>
            </div>
            <div v-if="resending">
                <img alt="Resending" src="@/assets/Icon_Syncing2.png" width="57px" class="form-header-icon" />
                <p>{{ $t("recover.form.resending") }}</p>
            </div>
        </div>
    </div>
</template>

<script lang="ts">
import Vue from "vue";
import CommonComponents from "@/views/shared";

import { required, email, minLength, sameAs } from "vuelidate/lib/validators";
import Logo from "@/views/shared/Logo.vue";

export default Vue.extend({
    name: "RecoverAccountView",
    components: {
        ...CommonComponents,
        Logo,
    },
    data(): {
        form: {
            email: string;
        };
        resending: boolean;
        attempted: boolean;
        busy: boolean;
    } {
        return {
            form: {
                email: "",
            },
            resending: false,
            attempted: false,
            busy: false,
        };
    },
    validations: {
        form: {
            email: {
                required,
                email,
            },
        },
    },
    methods: {
        async save(): Promise<void> {
            this.$v.form.$touch();
            if (this.$v.form.$pending || this.$v.form.$error) {
                return;
            }
            this.busy = true;
            await this.$services.api
                .sendResetPasswordEmail(this.form.email)
                .then(() => (this.attempted = true))
                .finally(() => (this.busy = true));
        },
        async resend(): Promise<void> {
            this.resending = true;
            await this.save().finally(() => (this.resending = false));
        },
    },
});
</script>

<style scoped lang="scss">
@import "../../scss/forms";

.reset-instructions {
    margin-bottom: 50px;
}

.form-submit {
    margin-top: 80px;

    @include bp-down($xs) {
        margin-top: 70px;
    }
}

.form-group {
    margin-top: 50px;
}

.form.success {
    .form-submit {
        margin-top: 50px;
    }
}

.form:not(.success) .form-subtitle {
    margin-top: -25px;
}
</style>
