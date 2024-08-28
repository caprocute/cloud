<template>
    <div :class="['sidebar', { open: isOpen }]" @click.stop>
        <button class="sidebar-toggle" @click="toggleSidebar"><i class="icon icon-filter"></i></button>
        <div class="sidebar-content">
            <div class="heading">{{ $t("map.sidebar.viewing.heading", { stationsLength: 10 }) }}</div>
            <div class="update-map-results-checkbox">
                <input id="updateResultsBasedOnMap" type="checkbox" @change="onUpdateResultsBasedOnMap" />
                <label for="updateResultsBasedOnMap">{{ $t("map.sidebar.viewing.updateMapCheckbox") }}</label>
            </div>
            <!--
            <button class="button">{{ $t("map.sidebar.viewing.exploreBtn") }}</button>
-->
            <div class="station-list">
                <div class="station-list-item" v-for="station in mapped.stations" v-bind:key="station.id">
                    <StationSummaryContent ref="summaryContent" :station="station">
                        <template #top-right-actions>
                            <img
                                :alt="$tc('station.navigateToStation')"
                                class="navigate-button"
                                src="@/assets/tooltip-fieldkit.svg"
                                @click="openStationPageTab"
                            />
                        </template>
                    </StationSummaryContent>
                </div>
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
        onUpdateResultsBasedOnMap(event) {
            console.log("Radoi emit");
            this.$emit("update-results-based-on-map", event.target.checked);
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
    width: 480px;
    transform: translateX(-100%);
    transition: transform 0.3s ease, transform 0.3s ease;
    border: solid 1px #f4f5f7;
    background-color: #fff;
    z-index: 1000;
    padding: 20px;
    text-align: left;
    display: flex;
    flex-direction: column;
}

.sidebar-toggle {
    position: absolute;
    left: 520px;
    top: 120px;
    z-index: $z-index-top;
    padding: 9px 8px;
    box-shadow: 0 2px 4px 0 rgba(0, 0, 0, 0.13);
    border: solid 1px #f4f5f7;
    background-color: #fff;

    .icon {
        font-size: 20px;
    }
}

.heading {
    font-size: 25px;
    font-weight: 900;
    margin-bottom: 7px;
}

.sidebar.open {
    transform: translateX(0);
}

.sidebar-content {
    padding: 20px;
    height: 100%;
    box-sizing: border-box;
    display: flex;
    flex-direction: column;
}

.button {
    font-weight: 900;
    font-size: 14px;
    font-family: $font-family-fieldkit-medium;
}

.station-list-item {
    padding: 27px 18px 25px 25px;
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

        .navigate-button {
            position: absolute;
            right: 0;
            top: 0;
            cursor: pointer;
        }

        .image-container img {
            border-radius: 5px;
        }
    }
}

.update-map-results-checkbox {
    font-size: 14px;
    color: #000;
    display: flex;
    align-items: end;
    margin-bottom: 23px;

    input {
        margin-right: 8px;
    }

    label {
        user-select: none;
    }
}

.station-list {
    flex-grow: 1;
    overflow-y: auto;
    display: flex;
    flex-direction: column;
    width: 100%;
    padding-right: 28px;
    padding-bottom: 120px;
}
</style>
