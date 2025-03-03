<template>
    <div class="h-100">
        <ExportChartButton v-if="!settings.tiny" :vega="vega"></ExportChartButton>
        <div ref="vegaContainer" class="viz linechart h-100"></div>
        <div v-if="isLoading" class="loading-container">
            <Spinner class="spinner" />
        </div>
    </div>
</template>

<script lang="ts">
import _ from "lodash";
import { isMobile } from "@/utilities";
import Vue, { PropType } from "vue";
import { default as vegaEmbed, VisualizationSpec } from "vega-embed";

import { TimeRange } from "../common";
import { SeriesData, TimeZoom } from "../viz";
import { ChartSettings } from "./SpecFactory";
import chartStyles from "./chartStyles";
import { TimeSeriesSpecFactory } from "./TimeSeriesSpecFactory";
import ExportChartButton from "@/views/viz/vega/ExportChartButton.vue";
import { ActionTypes } from "@/store";

type DragTimeSignal = [number, number] | null;

function roundForDisplay(value: number): number {
    for (let i = 1; i < 6; ++i) {
        const factor = Math.pow(10, i);
        const rounded = Math.round(value * factor) / factor;
        if (rounded !== 0) {
            return rounded;
        }
    }
    return value;
}

export default Vue.extend({
    name: "LineChart",
    components: {
        Spinner,
         ExportChartButton,
    },
    props: {
        series: {
            type: Array as PropType<SeriesData[]>,
            required: true,
        },
        settings: {
            type: Object as PropType<ChartSettings>,
            default: () => (isMobile() ? ChartSettings.DefaultMobile : ChartSettings.makeDefaultDesktop()),
        },
    },
    data(): {
        vega: unknown | undefined;
        isLoading: boolean;
    } {
        return {
            vega: undefined,
            isLoading: false,
        };
    },
    async mounted(): Promise<void> {
        await this.refresh();
    },
    watch: {
        async series(): Promise<void> {
            await this.refresh();
        },
    },
    methods: {
        async refresh(): Promise<void> {
            this.isLoading = true;

            if (this.series.length == 0) {
                this.isLoading = false;
                return;
            }

            const brushable = !this.settings.mobile;
            const draggable = !brushable;
            const factory = new TimeSeriesSpecFactory(this.series, this.settings, brushable, draggable);

            const spec = factory.create();
            const vegaContainer = this.$refs.vegaContainer as HTMLElement;

            const vegaInfo = await vegaEmbed(vegaContainer as HTMLElement, spec as VisualizationSpec, {
                renderer: "svg",
                tooltip: {
                    offsetX: -50,
                    offsetY: 50,
                    formatTooltip: (tooltip, sanitize) => {
                        const roundedValue = roundForDisplay(tooltip.value);
                        const withUoM = [roundedValue, tooltip.unitOfMeasure || " "].join(" ");
                        return `<h3><span class="tooltip-color" style="color: ${sanitize(this.getTooltipColor(tooltip.name))};">■</span>
                                        ${sanitize(tooltip.title)}</h3>
                                        <p class="value">${sanitize(withUoM)}</p>
                                        <p class="time">${sanitize(tooltip.time)}</p>`;
                    },
                },
                downloadFileName: this.getFileName(this.series),
                actions: false,
                scaleFactor: 2,
                padding: this.settings.tiny ? undefined : this.settings.mobile ? { left: 0, right: 10 } : { left: 10, right: 50 },
            });

            this.vega = vegaInfo;

            if (!this.settings.tiny) {
                if (brushable) {
                    let scrubbed = [];

                    vegaInfo.view.addSignalListener("brush", (_, value) => {
                        scrubbed = value.time;
                    });

                    vegaInfo.view.addEventListener("mouseup", () => {
                        if (scrubbed.length == 2) {
                            this.$emit("time-zoomed", new TimeZoom(null, new TimeRange(scrubbed[0], scrubbed[1])));
                        }
                    });

                    // Watch for brush drag outside the window
                    vegaInfo.view.addEventListener("mousedown", (e) => {
                        window.addEventListener("mouseup", (e) => {
                            if (e.target instanceof Element) {
                                if (scrubbed.length == 2 && e.target && e.target.nodeName !== "path") {
                                    this.$emit("time-zoomed", new TimeZoom(null, new TimeRange(scrubbed[0], scrubbed[1])));
                                }
                            }
                        });
                    });
                } else {
                    /*
                    vegaInfo.view.addSignalListener("down", async (_, value: DragTimeSignal) => {
                        console.log("down", value);
                    });

                    vegaInfo.view.addSignalListener("xcur", async (_, value: DragTimeSignal) => {
                        console.log("xcur", value);
                    });

                    vegaInfo.view.addSignalListener("drag_delta", async (_, value: DragTimeSignal) => {
                        console.log("delta", value);
                    });

                    vegaInfo.view.addSignalListener("chart_clip_size", async (_, value) => {
                        console.log("chart_clip_size", value);
                    });
                    */

                    vegaInfo.view.addSignalListener("visible_times_calc", async (_, value: DragTimeSignal) => {
                        if (value) {
                            this.$emit("time-dragged", new TimeZoom(null, new TimeRange(value[0], value[1])));
                        }
                    });

                    vegaInfo.view.addSignalListener("drag_time", async (_, value: DragTimeSignal) => {
                        if (value) {
                            this.$emit("time-zoomed", new TimeZoom(null, new TimeRange(value[0], value[1])));
                        }
                    });
                }
            }

            console.log("viz: vega:ready", {
                state: vegaInfo.view.getState(),
                // layouts: vegaInfo.view.data("all_layouts"),
            });

            this.isLoading = false;
        },
        getTooltipColor(name: string): string {
            if (name === "LEFT") {
                return chartStyles.primaryLine.stroke;
            }
            if (name === "RIGHT") {
                return chartStyles.secondaryLine.stroke;
            } else {
                return "#ccc";
            }
        },
        getFileName(series: { vizInfo: { station: { name: string }; name: string } }[]): string {
            const stationGroups: Record<string, string[]> = series.reduce((acc, item) => {
                const stationName = item.vizInfo.station.name;
                const sensorName = item.vizInfo.name;

                if (!acc[stationName]) {
                    acc[stationName] = [];
                }
                acc[stationName].push(sensorName);
                return acc;
            }, {} as Record<string, string[]>);

            const entries = Object.entries(stationGroups);

            if (entries.length === 1) {
                const [stationName, sensorNames] = entries[0];
                if (sensorNames.length === 1) {
                    return `${stationName}-${sensorNames[0]}`;
                } else {
                    return `${stationName} ${sensorNames.join(" - ")}`;
                }
            } else if (entries.length === 2) {
                const [[station1Name, sensor1Names], [station2Name, sensor2Names]] = entries;
                if (sensor1Names.length === 1 && sensor2Names.length === 1) {
                    return `${station1Name}-${sensor1Names[0]}_${station2Name}-${sensor2Names[0]}`;
                }
            }

            const fileName: string = entries
                .map(([stationName, sensorNames]) => {
                    return `${stationName}-${sensorNames.join("-")}`;
                })
                .join(" ");

            return fileName;
        },
    },
});
</script>

<style lang="scss">
@import "src/scss/mixins";

.viz {
    width: 100%;
}

.vega-embed summary {
    border-radius: 0px !important;
    height: 1em;
    display: flex;
    align-items: center;
    margin-right: 3.2em !important;
    opacity: 1 !important;

    @include bp-down($sm) {
        bottom: -195px;
        top: unset !important;
        left: 50%;
        transform: translateX(-50%);
        width: 80px;

        span {
            font-size: 14px;
            font-family: $font-family-bold;
        }
    }
}
.vega-embed summary svg {
    width: 16px !important;
    height: 16px !important;
    display: inline-block;

    @include bp-down($sm) {
        width: 20px !important;
        height: 20px !important;
    }
}
.vega-embed .vega-actions {
    right: 3em !important;

    @include bp-down($sm) {
        bottom: -225px;
        top: unset !important;
        right: 50% !important;
    }
}

.vega-embed.has-actions {
    @include bp-down($sm) {
        padding-right: 0 !important;
    }
}
.save-label {
    font-size: 12px;
    margin-left: 5px;
}
</style>
