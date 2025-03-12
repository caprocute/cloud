<template>
    <div class="modal-overlay" v-if="show" @click.self="close">
        <div class="modal-content">
            <h3>Review Reported Content</h3>
            <div class="content-details">
                <p><strong>Post Type:</strong> {{ request.postType }}</p>
                <p><strong>Reported By:</strong> {{ request.reportedByName || request.reportedBy }}</p>
                <p><strong>Content:</strong></p>
                <div class="content-box">
                    <TipTap 
                        :value="content"
                        :readonly="true"
                        :showSaveButton="false"
                    />
                </div>
            </div>
            <div class="actions">
                <button class="button delete-btn" @click="handleAction('delete')">
                    Delete Content
                </button>
                <button class="button keep-btn" @click="handleAction('keep')">
                    Keep Content
                </button>
                <button class="button cancel-btn" @click="close">
                    Cancel
                </button>
            </div>
        </div>
    </div>
</template>

<script lang="ts">
import Vue from "vue";
import TipTap from "@/views/shared/Tiptap.vue";

export default Vue.extend({
    name: "ModerationReviewModal",
    components: {
        TipTap,
    },
    props: {
        show: {
            type: Boolean,
            required: true,
        },
        request: {
            type: Object,
            required: true,
        },
        content: {
            type: String,
            required: true,
        },
    },
    methods: {
        close() {
            this.$emit("close");
        },
        async handleAction(action: 'delete' | 'keep') {
            try {
                await this.$services.api.acknowledgeModerationRequest(
                    this.request.id,
                    action
                );
                this.$emit("action-complete");
                this.close();
            } catch (error) {
                console.error("Error handling moderation action:", error);
            }
        },
    },
});
</script>

<style scoped>
.modal-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    justify-content: center;
    align-items: center;
    z-index: 1000;
}

.modal-content {
    background: white;
    padding: 2rem;
    border-radius: 4px;
    max-width: 600px;
    width: 90%;
}

.content-box {
    background: #f5f5f5;
    padding: 1rem;
    margin: 1rem 0;
    border-radius: 4px;
    max-height: 300px;
    overflow-y: auto;
    white-space: pre-wrap;
}

.actions {
    display: flex;
    gap: 1rem;
    justify-content: flex-end;
    margin-top: 1rem;
}

.delete-btn {
    background: #dc3545;
    color: white;
}

.keep-btn {
    background: #28a745;
    color: white;
}

.cancel-btn {
    background: #6c757d;
    color: white;
}
</style> 