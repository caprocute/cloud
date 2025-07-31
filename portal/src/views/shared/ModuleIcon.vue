<template>
    <div class="hoverable-item">
        <img alt="Module icon" class="module-icon" :src="module.url" />
        <span class="tooltip-text">{{ $t(module.name) }}</span>
    </div>
</template>

<script lang="ts">
import Vue, { PropType } from "vue";

export default Vue.extend({
    name: "ModuleIcon",
    props: {
        module: {
            type: Object as PropType<{ url: string; name: string }>,
            required: true,
        },
    },
});
</script>

<style lang="scss" scoped>
@use "src/scss/mixins";
@use "src/scss/variables";

.hoverable-item {
    position: relative;

    @include mixins.attention() {
        .tooltip-text {
            visibility: visible;
            opacity: 1;
        }
    }
}

.module-icon {
    width: 40px;
    height: 40px;
    margin-right: 10px;
}

.tooltip-text {
    visibility: hidden;
    opacity: 0;
    transition: opacity 0.25s;
    padding: 8px 16px;
    border-radius: 2px;
    box-shadow: 0 2px 4px 0 rgba(0, 0, 0, 0.24);
    border: solid 1px #f4f5f7;
    background-color: #fff;
    font-size: 14px;
    white-space: nowrap;
    transform: translateX(-50%);
    z-index: variables.$z-index-top;
    @include mixins.position(absolute, null null calc(-100% + 10px) 50%);

    @include mixins.bp-down(variables.$sm) {
        bottom: calc(-100% + 15px);
    }
}
</style>
