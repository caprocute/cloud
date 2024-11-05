<template>
    <div v-if="viewingSummary && station" class="station-map-summary" :class="{ open: isOpen }">
        <div class="station-header">
            <div class="station-heading">
                <div class="station-name">{{ station.name }}</div>
                <a class="btn-close" @click="wantCloseSummary"><i class="icon icon-close"></i></a>
                <a>
                    <img
                        :alt="$tc('station.navigateToStation')"
                        class="navigate-button"
                        :src="$loadAsset(interpolatePartner('tooltip-') + '.svg')"
                        @click="openStationPageTab"
                    />
                </a>
            </div>

            <template v-if="isCustomisationEnabled()">
                <div class="row where-row">
                    <div v-if="neighborhood || borough" class="flex flex-al-center">
                        <i class="icon icon-location" />
                        <template v-if="neighborhood">{{ neighborhood }}</template>
                        <template v-if="neighborhood && borough">{{ ", " }}</template>
                        <template v-if="borough">{{ borough }}</template>
                    </div>
                    <div v-if="deploymentDate || deployedBy" class="flex flex-al-center">
                        <i class="icon icon-calendar" />
                        <template v-if="deploymentDate">{{ $t("station.deployedOn") }} {{ deploymentDate }}</template>
                        <template v-if="deployedBy">{{ " " }}{{ $t("station.by") }} {{ deployedBy }}</template>
                    </div>
                </div>
            </template>

            <template v-else>
                <div
                    v-if="stationLocationName || station.placeNameNative || station.placeNameOther || station.placeNameNative"
                    class="row where-row"
                >
                    <div class="flex flex-al-center">
                        <template v-if="stationLocationName || station.placeNameOther">
                            <i class="icon icon-location" />
                            <template>
                                {{ stationLocationName ? stationLocationName : station.placeNameOther }}
                            </template>
                        </template>
                        <template v-if="station.placeNameNative">
                            <i class="icon icon-location" />
                            <span class="location-name">
                                {{ $t("station.nativeLands") }}
                                <span class="bold">{{ station.placeNameNative }}</span>
                            </span>
                        </template>
                    </div>
                </div>
            </template>
        </div>

        <StationPhoto :station="station" />

        <StationBattery :station="station"></StationBattery>

        <div class="tabs-container">
            <div class="tabs-nav">
                <a v-for="tab in tabs" :key="tab.id" :class="{ active: selectedTab === tab.id }" @click="selectedTab = tab.id">
                    {{ tab.label }}
                </a>
            </div>

            <!-- Tabs Content -->
            <div class="tabs-content">
                <div v-if="selectedTab == SummaryTabsEnum.explore">
                    <StationModules v-if="station.modules.length > 0" :station="station"></StationModules>
                    <template v-else>
                        {{ $tc("dataView.noData") }}
                    </template>
                </div>
                <div v-if="selectedTab == SummaryTabsEnum.fieldNotes">
                  <FieldNotes :stationName="station.name"></FieldNotes>

                </div>
                <div v-if="selectedTab == SummaryTabsEnum.details">
                    <StationProjects :stationId="station.id"></StationProjects>
                    <div v-if="station.modules.length > 0" class="details-row">
                        <span class="bold">{{ $tc("station.modules") }}</span>
                        <div class="station-modules ml-10">
                            <img
                                v-for="(module, moduleIndex) in station.modules"
                                v-bind:key="moduleIndex"
                                alt="Module icon"
                                :src="getModuleImg(module)"
                            />
                        </div>
                    </div>

                    <div v-if="station.firmwareNumber" class="details-row">
                        <span class="bold">{{ $tc("station.firmwareVersion") }}</span>
                        <span class="ml-10 small-light">{{ station.firmwareNumber }}</span>
                    </div>

                    <section v-if="!isCustomisationEnabled()" class="section-notes container-box">
                        <NotesForm v-bind:key="station.id" :station="station" :readonly="true" />
                    </section>
                </div>
            </div>
        </div>
    </div>
</template>

<script lang="ts">
import Vue, { PropType } from "vue";
import { mapGetters } from "vuex";

import CommonComponents from "@/views/shared";
import StationBattery from "@/views/station/StationBattery.vue";

import { ModuleSensorMeta, SensorDataQuerier, SensorMeta } from "@/views/shared/sensor_data_querier";
import { DecoratedReading, DisplayModule, VisibleReadings } from "@/store";

import { getBatteryIcon } from "@/utilities";
import { BookmarkFactory, ExploreContext, serializeBookmark } from "@/views/viz/viz";
import { getPartnerCustomizationWithDefault, interpolatePartner, isCustomisationEnabled, PartnerCustomization } from "./partners";
import { StationStatus } from "@/api";
import { CupertinoPane } from "cupertino-pane";
import TinyChart from "@/views/viz/TinyChart.vue";
import * as utils from "@/utilities";
import StationModules from "@/views/station/StationModules.vue";
import StationProjects from "@/views/station/StationProjects.vue";
import NotesForm from "@/views/notes/NotesForm.vue";
import FieldNotes from '@/views/fieldNotes/FieldNotes.vue';

enum SummaryTabsEnum {
    explore = "explore",
    fieldNotes = "fieldNotes",
    details = "details",
}

export default Vue.extend({
    name: "StationsMapSummary",
    components: {
      FieldNotes,
        NotesForm,
        StationProjects,
        StationModules,
        ...CommonComponents,
        StationBattery,
    },
    props: {
        station: {
            type: Object,
            required: true,
        },
        explore: {
            type: Boolean,
            default: true,
        },
        exploreContext: {
            type: Object as PropType<ExploreContext>,
            default: () => {
                return new ExploreContext();
            },
        },
        sensorDataQuerier: {
            type: Object as PropType<SensorDataQuerier>,
            required: false,
        },
        visibleReadings: {
            type: Number as PropType<VisibleReadings>,
            default: VisibleReadings.Current,
        },
        hasCupertinoPane: {
            type: Boolean,
            default: false,
        },
    },
    filters: {
        integer: (value) => {
            if (!value) return "";
            return Math.round(value);
        },
    },
    watch: {
        station(this: any) {
            if (this.cupertinoPane) {
                this.cupertinoPane.present({ animate: true });
            }
        },
    },
    data(): {
        viewingSummary: boolean;
        sensorMeta: SensorMeta | null;
        StationStatus: any;
        isMobileView: boolean;
        cupertinoPane: CupertinoPane | null;
        isOpen: boolean;
        tabs: any[];
        selectedTab: SummaryTabsEnum;
    } {
        return {
            viewingSummary: true,
            sensorMeta: null,
            StationStatus: StationStatus,
            isMobileView: window.screen.availWidth < 500,
            cupertinoPane: null,
            isOpen: true,
            tabs: [
                { id: SummaryTabsEnum.explore, label: this.$tc("stationsMapSummary.tabs.explore") },
                { id: SummaryTabsEnum.fieldNotes, label: "Field Notes" },
                { id: SummaryTabsEnum.details, label: "Station Details" },
            ],
            selectedTab: SummaryTabsEnum.details,
        };
    },
    async mounted() {
        if (this.hasCupertinoPane && this.isMobileView) {
            this.initCupertinoPane();
        }
        this.sensorMeta = await this.sensorDataQuerier.querySensorMeta();
    },
    destroyed() {
        this.destroyCupertinoPane();
    },
    computed: {
        ...mapGetters({ projectsById: "projectsById" }),
        visibleSensor(): ModuleSensorMeta | null {
            const primarySensor = this.station.primarySensor;
            if (this.sensorMeta && primarySensor) {
                return this.sensorMeta.findSensorByKey(primarySensor.fullKey);
            }
            return null;
        },
        hasData(): boolean {
            return this.station.hasData;
        },
        decoratedReading(): DecoratedReading | null {
            const readings = this.station.getDecoratedReadings(this.visibleReadings);
            if (readings && readings.length > 0) {
                return readings[0];
            }
            return null;
        },
        visibleReadingValue(): number | null {
            const reading: DecoratedReading | null = this.decoratedReading;
            if (reading) {
                return reading.value;
            }
            return null;
        },
        latestPrimaryLevel(): any {
            const reading: DecoratedReading | null = this.decoratedReading;
            if (reading) {
                return reading?.thresholdLabel;
            }
            return null;
        },
        latestPrimaryColor(): string {
            const reading: DecoratedReading | null = this.decoratedReading;
            if (reading === null) {
                return getPartnerCustomizationWithDefault().latestPrimaryNoDataColor;
            }
            if (reading) {
                return reading?.color;
            }
            return "#00CCFF";
        },
        stationLocationName(): string {
            return this.partnerCustomization().stationLocationName(this.station);
        },
        // TODO: refactor using functions from partner.ts
        neighborhood(): string {
            return this.getAttributeValue("Neighborhood");
        },
        borough(): string {
            return this.getAttributeValue("Borough");
        },
        deploymentDate(): string {
            return this.getAttributeValue("Deployment Date");
        },
        deployedBy(): string {
            return this.getAttributeValue("Deployed By");
        },
        SummaryTabsEnum() {
            return SummaryTabsEnum;
        },
    },
    methods: {
        isCustomisationEnabled,
        viewSummary() {
            this.viewingSummary = true;
        },
        onClickExplore() {
            const bm = BookmarkFactory.forStation(this.station.id, this.exploreContext);
            return this.$router.push({
                name: "exploreBookmark",
                query: { bookmark: serializeBookmark(bm) },
            });
        },
        getBatteryIcon() {
            return this.$loadAsset(getBatteryIcon(this.station.battery));
        },
        wantCloseSummary() {
            this.$emit("close");
        },
        openStationPageTab() {
            const routeData = this.$router.resolve({ name: "viewStationFromMap", params: { stationId: this.station.id } });
            window.open(routeData.href, "_blank");
        },
        interpolatePartner(baseString) {
            return interpolatePartner(baseString);
        },
        isPartnerCustomisationEnabled(): boolean {
            return isCustomisationEnabled();
        },
        async initCupertinoPane(): Promise<void> {
            const paneContentEl = this.$refs["paneContent"] as HTMLDivElement;
            const generalRowEl = (this.$refs["summaryContent"] as Vue).$refs["summaryGeneralRow"] as HTMLDivElement;
            this.cupertinoPane = new CupertinoPane(".js-cupertinoPane", {
                parentElement: "body",
                breaks: {
                    top: { enabled: true, height: paneContentEl.scrollHeight, bounce: true },
                    // add padding top of container and margin of general row
                    middle: { enabled: true, height: generalRowEl.scrollHeight + 25 + 10, bounce: true },
                    bottom: { enabled: true, height: 0 },
                },
                bottomClose: true,
                buttonDestroy: false,
            });
            this.cupertinoPane.present({ animate: true });
        },
        destroyCupertinoPane(): void {
            if (this.cupertinoPane) {
                this.cupertinoPane.destroy();
            }
        },
        partnerCustomization(): PartnerCustomization {
            return getPartnerCustomizationWithDefault();
        },
        getAttributeValue(attrName: string): any {
            if (this.station) {
                const value = this.station.attributes.find((attr) => attr.name === attrName)?.stringValue;
                return value ? value : null;
            }
        },
        getModuleName(module: DisplayModule): string {
            return module.label || this.$tc(module.name.replace("modules.", "fk."));
        },
        getModuleKey(module: DisplayModule): string {
            return module.name.replace("modules.", "fk.");
        },
        getModuleImg(module: DisplayModule): string {
            return this.$loadAsset(utils.getModuleImg(module));
        },
    },
});
</script>

<style scoped lang="scss">
@import "../../scss/mixins";

.station-map-summary {
    height: 100%;
    width: 0;
    transform: translateX(-100%);
    transition: transform 0.3s ease;
    border: solid 1px #f4f5f7;
    background-color: #fff;
    box-shadow: 0 2px 4px 0 rgba(0, 0, 0, 0.07);
    z-index: 1000;
    text-align: left;
    display: flex;
    flex-direction: column;
    box-sizing: border-box;
    margin-top: 1px;
    margin-left: 1px;
}

.station-map-summary.open {
    transform: translateX(0);
    width: 430px;

    .sidebar-toggle {
        left: 480px;
    }
}

.station-heading {
    margin-bottom: 8px;
    display: flex;
    align-items: center;
}

.location-name {
    font-size: 14px;
}

.station-header {
    padding: 40px 25px 30px;
}

.station-name {
    font-size: 20px;
    font-weight: 900;
    color: #2c3e50;
}

.station-photo {
    height: 200px;
    width: 100%;
    object-fit: cover;
}

.icon-location {
    margin-right: 7px;
    margin-top: -2px;
}

.station-battery-container {
    padding: 20px 16px 30px 25px;
}

::v-deep .battery {
    width: 25px;
    height: 14px;
    padding-right: 7px;
    margin-bottom: -2px;
}

.station-hover-summary {
    position: absolute;
    background-color: #ffffff;
    border: solid 1px #d8dce0;
    border-radius: 3px;
    z-index: 2;
    display: flex;
    flex-direction: column;
    padding: 27px 20px 17px;
    width: 389px;
    box-sizing: border-box;

    ::v-deep .station-name {
        font-size: 16px;
    }

    * {
        font-family: $font-family-light;
    }

    @include bp-down($xs) {
        width: 100% !important;
        left: 0 !important;
        top: 0 !important;
        transform: translate(0, 0) !important;
        border-radius: 10px;
        padding: 25px 10px 12px 10px;

        .close-button {
            display: none;
        }

        .navigate-button {
            width: 14px;
            height: 14px;
            right: -3px;
            top: -17px;
        }

        .image-container {
            flex-basis: 62px;
            height: 62px;
            margin-right: 10px;
        }

        .station-name {
            font-size: 14px;
        }

        .explore-button {
            margin-top: 15px;
            margin-bottom: 10px;
        }
    }
}

.location-coordinates {
    display: flex;
    flex-direction: row;
    justify-content: space-between;
    flex-basis: 50%;
}

.location-coordinates .coordinate {
    display: flex;
    flex-direction: column;

    > div {
        margin-bottom: 2px;

        &:nth-of-type(2) {
            font-size: 12px;
        }
    }
}

.close-button {
    cursor: pointer;
    @include position(absolute, -7px -5px null null);
}

.navigate-button {
    margin: 0 8px;
}

.readings-container {
    margin-top: 7px;
    padding-top: 9px;
    border-top: 1px solid #f1eeee;
    text-align: left;
    font-size: 14px;
    color: #2c3e50;
}

.readings-container div.title {
    padding-bottom: 13px;
    font-family: var(--font-family-medium);

    body.floodnet & {
        font-family: var(--font-family-bold);
    }
}

.explore-button {
    font-size: 18px;
    font-family: var(--font-family-bold);
    color: #ffffff;
    text-align: center;
    padding: 10px;
    margin: 24px 0 14px 0px;
    background-color: var(--color-secondary);
    border: 1px solid rgb(215, 220, 225);
    border-radius: 4px;
    cursor: pointer;
}

::v-deep .reading {
    height: 35px;

    .name {
        font-size: 11px;
    }
}

.latest-primary {
    font-size: 12px;
    font-family: $font-family-bold;
    @include flex(center, flex-end);

    @include bp-down($xs) {
        margin-top: 10px;
    }

    i {
        font-style: normal;
        font-size: 10px;
        font-weight: 900;
        border-radius: 50%;
        padding: 5px;
        color: #fff;
        margin-left: 5px;
        min-width: 1.2em;
        text-align: center;
    }

    .no-data {
        color: #777a80;
        font-family: $font-family-bold;

        body.floodnet & {
            color: #cccccc;
        }
    }
}

.btn-close {
    position: absolute;
    top: 40px;
    right: 20px;
}

.tabs-container {
    border-top: solid 1px var(--color-border);
}

.tabs-nav {
    display: flex;
    justify-content: space-between;
    padding: 30px 20px 25px;

    > a {
        padding: 4px 4px;

        &.active {
            border-bottom: 1.5px solid var(--color-dark);
        }
    }
}

.tabs-content {
    padding: 25px;
    border-top: solid 1px #d8dce0;
}

::v-deep .module-data-item {
    flex: 0 0 100%;
}

.station-modules {
    margin-left: 10px;
    flex-wrap: wrap;
    @include flex;

    img {
        margin-right: 8px;
        margin-bottom: 5px;
        width: 25px;
        height: 25px;
    }
}

.details-row {
    display: flex;
    align-items: center;
    padding: 15px 0;
    border-bottom: 1px solid var(--color-border);
    font-size: 14px;

    &:nth-of-type(1) {
        padding-top: 0;
    }
}

.station-projects {
    margin: 10px 0;
    color: var(--color-dark);
}
</style>
