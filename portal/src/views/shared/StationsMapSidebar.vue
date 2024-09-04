<template>
    <div :class="['sidebar', { open: isOpen }]" @click.stop>
        <button class="sidebar-toggle" @click="toggleSidebar"><i class="icon icon-filter"></i></button>
        <div class="sidebar-content">
            <div class="heading">{{ $t("map.sidebar.viewing.heading", { stationsLength: stations.length }) }}</div>
            <label class="update-map-results-checkbox checkbox">
                <input id="updateResultsBasedOnMap" type="checkbox" @change="onUpdateResultsBasedOnMap" />
                <span class="checkbox-btn"></span>
                {{ $t("map.sidebar.viewing.updateMapCheckbox") }}
            </label>
            <!--
            <button class="button">{{ $t("map.sidebar.viewing.exploreBtn") }}</button>
-->
            <div class="station-list">
                <div v-if="stations.length === 0">{{ $t("map.sidebar.viewing.noStationsOnMap") }}</div>
                <div class="station-list-item" v-for="station in stations" v-bind:key="station.id">
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

export default Vue.extend({
    name: "StationsMapSidebar",
    components: { StationSummaryContent },
    props: {
        stations: {
            required: true,
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
            this.$emit("toggle");
        },
        openStationPageTab() {
            const routeData = this.$router.resolve({ name: "viewStationFromMap", params: { stationId: this.station.id } });
            window.open(routeData.href, "_blank");
        },
        onUpdateResultsBasedOnMap(event) {
            this.$emit("update-results-based-on-map", event.target.checked);
        },
    },
});
</script>

<style scoped lang="scss">
@import "src/scss/variables";

.sidebar {
    height: 100%;
    width: 0;
    transform: translateX(-100%);
    transition: transform 0.3s ease;
    border: solid 1px #f4f5f7;
    background-color: #fff;
    z-index: 1000;
    text-align: left;
    display: flex;
    flex-direction: column;
    box-sizing: border-box;
    margin-top: 1px;
    margin-left: 1px;
}

.sidebar-toggle {
    position: absolute;
    left: 0;
    top: 140px;
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
    width: 480px;
    padding: 20px;

    .sidebar-toggle {
        left: 480px;
    }
}

.sidebar-content {
    height: 100%;
    box-sizing: border-box;
    display: flex;
    flex-direction: column;
    overflow: hidden;
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
    user-select: none;

    input {
        margin-right: 8px;
        margin-left: 0;
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
