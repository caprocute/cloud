<template>
    <ul class="flex flex-wrap flex-space-between module-data-container">
        <li class="module-data-item" v-for="module in station.modules" v-bind:key="module.id" @click="onModuleClick(module.id)">
            <h3 class="module-data-title">
                <img alt="Module icon" :src="getModuleImg(module)" />
                {{ getModuleName(module) }}
            </h3>
            <TinyChart
                :ref="'tinyChart-' + module.id"
                :moduleKey="getModuleKey(module)"
                :station-id="station.id"
                :station="station"
                :querier="sensorDataQuerier"
            />
        </li>
    </ul>
</template>

<script lang="ts">
import Vue, { PropType } from "vue";
import { DisplayModule, DisplayStation, StationStatus } from "@/store";
import * as utils from "@/utilities";
import TinyChart from "@/views/viz/TinyChart.vue";
import { BookmarkFactory, serializeBookmark } from "@/views/viz/viz";
import { SensorDataQuerier } from "@/views/shared/sensor_data_querier";

export default Vue.extend({
    name: "StationModules",
    components: { TinyChart },
    props: {
        station: {
            type: Object as PropType<DisplayStation>,
            default: null,
        },
    },
    data(): {
        sensorDataQuerier: SensorDataQuerier;
    } {
        return {
            sensorDataQuerier: new SensorDataQuerier(this.$services.api),
        };
    },
    methods: {
        getModuleImg(module: DisplayModule): string {
            return this.$loadAsset(utils.getModuleImg(module));
        },
        getModuleName(module: DisplayModule): string {
            return module.label || this.$tc(module.name.replace("modules.", "fk."));
        },
        getModuleKey(module: DisplayModule): string {
            return module.name.replace("modules.", "fk.");
        },
        onModuleClick(moduleId: number) {
            const tinyChartComp = this.$refs["tinyChart-" + moduleId];
            if (tinyChartComp && tinyChartComp[0]) {
                const vizData = tinyChartComp[0].vizData;
                if (vizData) {
                    const bm = BookmarkFactory.forSensor(this.station.id, vizData.vizSensor, vizData.timeRange);
                    const url = this.$router.resolve({
                        name: "exploreBookmark",
                        query: { bookmark: serializeBookmark(bm) },
                    }).href;
                    window.open(url, "_blank");
                }
            }
        },
    },
});
</script>

<style scoped lang="scss">
@import "src/scss/variables";
@import "src/scss/mixins";

.module-data-container {
    gap: 20px;

    @include bp-down($sm) {
        gap: 10px;
    }
}

.module-data-item {
    flex: 1 1 calc(50% - 10px);
    min-width: 0;
    z-index: $z-index-top;

    @include bp-down($sm) {
        flex: 0 0 100%;
    }
}

.module-data-title {
    color: $color-primary;
    font-size: 12px;
    margin-bottom: 10px;
    cursor: pointer;
    margin-top: 0;
    display: flex;
    align-items: flex-end;

    img {
        margin-right: 7px;
        width: 19px;
        height: 19px;
    }
}
</style>
