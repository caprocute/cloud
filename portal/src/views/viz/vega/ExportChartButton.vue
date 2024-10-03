<template>
    <div class="vega-embed vega-embed--dummy">
        <details>
            <summary>
                <svg viewBox="0 0 20 20" fill="currentColor" stroke="none" stroke-width="1" stroke-linecap="round" stroke-linejoin="round">
                    <g id="icon_SaveAs" stroke="none" stroke-width="1" fill="none" fill-rule="evenodd" stroke-linecap="round">
                        <line
                            x1="7.96030045"
                            y1="1"
                            x2="7.96030045"
                            y2="11"
                            id="Path-2"
                            stroke="#2C3E50"
                            stroke-width="1.5"
                            stroke-linejoin="round"
                        ></line>
                        <polyline
                            id="Path-9"
                            stroke="#2C3E50"
                            stroke-width="1.5"
                            stroke-linejoin="bevel"
                            points="12.8961983 6.50366211 8.05585126 11 2.92245537 6.50366211"
                        ></polyline>
                        <polyline
                            id="Path-10"
                            stroke="#2C3E50"
                            stroke-width="1.5"
                            stroke-linejoin="round"
                            points="1 12.5363846 1 16.5 15.1181831 16.5 15.1181831 12.5363846"
                        ></polyline>
                    </g>
                </svg>
                <span class="save-label">{{ $t("dataView.saveAs") }}</span>
            </summary>
            <div class="vega-actions">
                <a href="" @click.prevent="exportAsSVG()">{{ $t("dataView.saveAsSvg") }}</a>
                <a href="" @click.prevent="exportAsPNG()">{{ $t("dataView.saveAsPng") }}</a>
            </div>
        </details>
    </div>
</template>

<script lang="ts">
import Vue, { PropType } from "vue";
import { View } from "vega";

export default Vue.extend({
    name: "ExportChartButton",
    props: {
        vega: {
            required: true,
        },
    },
    methods: {
        // Reusable download helper
        downloadFile(content: string | Blob, fileName: string, mimeType: string) {
            const blob = typeof content === "string" ? new Blob([content], { type: mimeType }) : content;

            const link = document.createElement("a");
            const url = URL.createObjectURL(blob);
            link.href = url;
            link.download = fileName;
            link.click();
            URL.revokeObjectURL(url);
        },

        async exportAsPNG() {
            if (!this.vega) return;

            const view = (this.vega as { view: View }).view;
            const exportWidth = 2400;
            const exportHeight = 800;

            try {
                const canvas = await view.toCanvas(4);
                const exportCanvas = document.createElement("canvas");
                exportCanvas.width = exportWidth;
                exportCanvas.height = exportHeight;

                const context = exportCanvas.getContext("2d");
                context?.drawImage(canvas, 0, 0, exportWidth, exportHeight);

                exportCanvas.toBlob((blob) => {
                    if (blob) {
                        this.downloadFile(blob, "chart.png", "image/png");
                    }
                });
            } catch (error) {
                console.error("Error exporting the chart as PNG:", error);
            }
        },

        async exportAsSVG() {
            if (!this.vega) return;

            const view = (this.vega as { view: View }).view;

            try {
                const svg = await view.toSVG();
                this.downloadFile(svg, "chart.svg", "image/svg+xml;charset=utf-8");
            } catch (error) {
                console.error("Error exporting the chart as SVG:", error);
            }
        },
    },
});
</script>
