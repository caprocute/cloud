<template>
    <button v-if="canCancel" @click="cancelReport" :disabled="isLoading">
        <i class="icon icon-close"></i>
        {{ isLoading ? cancelingText || "Canceling..." : labelText || "Cancel report" }}
    </button>
</template>

<script lang="ts">
import Vue from "vue";
import { PostType } from "@/api/api";
import { SnackbarStyle } from "@/store/modules/snackbar";
import { ActionTypes } from "@/store";

export default Vue.extend({
    name: "CancelReportLink",
    props: {
        postId: {
            type: Number,
            required: true,
        },
        postType: {
            type: String as () => PostType,
            required: true,
        },
        userHasReported: {
            type: Boolean,
            default: false,
        },
    },
    data() {
        return {
            isLoading: false,
        };
    },
    computed: {
        canCancel(): boolean {
            return this.userHasReported;
        },
        labelText(): string {
            try {
                return this.$t("cancelReport.label") as string;
            } catch {
                return "Cancel report";
            }
        },
        cancelingText(): string {
            try {
                return this.$t("cancelReport.canceling") as string;
            } catch {
                return "Canceling...";
            }
        },
        successText(): string {
            try {
                return this.$t("cancelReport.success") as string;
            } catch {
                return "Report canceled successfully!";
            }
        },
        errorText(): string {
            try {
                return this.$t("cancelReport.error") as string;
            } catch {
                return "Failed to cancel report. Please try again later.";
            }
        },
    },
    methods: {
        async cancelReport() {
            this.isLoading = true;
            try {
                await this.$services.api.cancelModerationRequest(this.postId, this.postType);
                this.$emit("report-canceled");
                this.$store.dispatch(ActionTypes.SHOW_SNACKBAR, {
                    message: this.successText,
                    type: SnackbarStyle.success,
                });
            } catch (error) {
                console.error("Error canceling report:", error);
                this.$store.dispatch(ActionTypes.SHOW_SNACKBAR, {
                    message: this.errorText,
                    type: SnackbarStyle.fail,
                });
            } finally {
                this.isLoading = false;
            }
        },
    },
});
</script>

<style scoped>
button {
    background: none;
    border: none;
    cursor: pointer;
    font-size: 12px;
    padding: 0;
    margin-left: 8px;
    display: inline-flex;
    align-items: center;
    gap: 3px;
    font-weight: bold;
}

button:hover {
    color: #333;
}

button:disabled {
    opacity: 0.6;
    cursor: not-allowed;
}

.icon {
    font-size: 10px;
}
</style>
