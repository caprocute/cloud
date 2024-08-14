<template>
    <div :class="['sidebar', { open: isOpen }]" @click.stop>
        <div class="toggle-button" @click="toggleSidebar">
            <slot name="toggle-button">Toggle</slot>
        </div>
        <div class="sidebar-content">
            <div class="heading">{{ $t("map.sidebar.viewing.heading", { stationsLength: 10 }) }}</div>
            <div>
                <input id="updateMapResults" type="checkbox" />
                <label for="updateMapResults">{{ $t("map.sidebar.viewing.updateMapCheckbox") }}</label>
            </div>
<!--
            <button class="button">{{ $t("map.sidebar.viewing.exploreBtn") }}</button>
-->
            <div class="station-list-item" v-for="station in mapped.stations" v-bind:key="station.id">
                <StationSummaryContent ref="summaryContent" :station="station">
                    <template #top-right-actions>
                        <img
                            :alt="$tc('station.navigateToStation')"
                            class="navigate-button"
                            :src="'tooltip-fieldkit.svg'"
                            @click="openStationPageTab"
                        />
                    </template>
                </StationSummaryContent>
            </div>
        </div>
    </div>
</template>

<script>
import Vue from "vue";
import StationSummaryContent from "@/views/shared/StationSummaryContent.vue";
import { MappedStations } from "@/store";

export default Vue.extend({
    name: "StationsMapSidebar",
    components: { StationSummaryContent },
    props: {
        mapped: {
            type: MappedStations,
        },
    },
    data() {
        return {
            isOpen: true,
        };
    },
    methods: {
        toggleSidebar() {
            this.isOpen = !this.isOpen;
        },
        openStationPageTab() {
            const routeData = this.$router.resolve({ name: "viewStationFromMap", params: { stationId: this.station.id } });
            window.open(routeData.href, "_blank");
        },
    },
});
</script>

<style scoped lang="scss">
@import "src/scss/variables";

.sidebar {
    position: absolute;
    top: 89px;
    left: 0;
    height: 100%;
    width: 0;
    max-width: 480px;
    overflow-x: hidden;
    transition: width 0.3s ease, transform 0.3s ease;
    border: solid 1px #f4f5f7;
    background-color: #fff;
    z-index: 1000;
    padding: 20px;
    text-align: left;
}

.heading {
    font-size: 25px;
    font-weight: 900;
    margin-bottom: 7px;
}

.sidebar.open {
    width: 480px;
}

.sidebar-content {
    padding: 20px;
    height: 100%;
    box-sizing: border-box;
}

.toggle-button {
    position: absolute;
    top: 10px;
    right: -50px;
    background-color: #444;
    color: white;
    padding: 10px 20px;
    cursor: pointer;
    z-index: 1001;
    transition: transform 0.3s ease;
}

.sidebar.open .toggle-button {
    transform: translateX(480px);
}

.button {
    font-weight: 900;
    font-size: 14px;
    font-family: $font-family-fieldkit-medium;
}

.station-list-item {
    padding: 17px 18px 24px 24px;
    border-radius: 3px;
    box-shadow: 0 2px 4px 0 rgba(0, 0, 0, 0.07);
    border: solid 1px #d8dce0;
    background-color: #fff;
    margin-bottom: 16px;

    ::v-deep {
        .station-name {
            font-size: 16px;
        }

        .image-container {
            flex: 0 0 93px;
            height: 93px;
        }
    }
}
</style>
