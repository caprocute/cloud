<template>
    <div class="vega-embed vega-embed--dummy">
        <details ref="vegaExportOptions">
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
import html2canvas from "html2canvas";
import { HTMLElement } from "@tiptap/vue-2";

export default Vue.extend({
    name: "ExportChartButton",
    props: {
        vega: {
            required: true,
        },
    },
    mounted() {
        document.addEventListener("click", this.handleClick);
    },
    beforeDestroy() {
        document.removeEventListener("click", this.handleClick);
    },
    methods: {
        handleClick() {
            const detailsElement = this.$refs.vegaExportOptions as HTMLHtmlElement;
            detailsElement.removeAttribute("open");
        },
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
            const htmlElement = document.getElementById("export-chart-content") as HTMLHtmlElement;

            try {
                const htmlCanvas = await html2canvas(htmlElement, { scale: 2 });
                const htmlImage = htmlCanvas.toDataURL("image/png");

                const canvas = await view.toCanvas(2);
                const exportWidth = Math.max(canvas.width, htmlCanvas.width);
                const exportHeight = canvas.height + htmlCanvas.height + 30;

                const exportCanvas = document.createElement("canvas");
                exportCanvas.width = exportWidth;
                exportCanvas.height = exportHeight;

                const context = exportCanvas.getContext("2d");
                const htmlImg = await this.loadImage(htmlImage);

                if (!context) return;

                context.fillStyle = "white";
                context.fillRect(0, 0, exportWidth, exportHeight);

                context.drawImage(htmlImg, 0, 0, exportWidth, htmlCanvas.height);

                const marginLeft = 90;
                const yOffset = htmlCanvas.height + 30;

                context.drawImage(canvas, marginLeft, yOffset, canvas.width + 70, canvas.height);

                exportCanvas.toBlob((blob) => {
                    if (blob) {
                        this.downloadFile(blob, "combined-chart.png", "image/png");
                    }
                });
            } catch (error) {
                console.error("Error exporting the chart as PNG:", error);
            }
        },

        async exportAsSVG() {
            const htmlElement = document.getElementById("export-chart-content") as HTMLHtmlElement;
            const canvas = await html2canvas(htmlElement);
            const htmlImage = canvas.toDataURL("image/png");

            const view = (this.vega as { view: View }).view;
            let svg;
            try {
                svg = await view.toSVG();
            } catch (error) {
                console.error("Error exporting the chart as SVG:", error);
                return;
            }

            const zoomFactor = 0.5;
            const scaledWidth = canvas.width * zoomFactor;
            const scaledHeight = canvas.height * zoomFactor;
            const marginTop = 30;
            const marginLeft = 50;

            const combinedSVG = `
              <svg xmlns="http://www.w3.org/2000/svg" width="${scaledWidth}" height="${scaledHeight + marginTop + 300}">
                  <foreignObject width="100%" height="${scaledHeight}">
                      <div xmlns="http://www.w3.org/1999/xhtml" style="transform: scale(${zoomFactor}); transform-origin: 0 0; width: ${
                canvas.width - 60
            }px; height: ${canvas.height}px;">
                                <img src="${htmlImage}" style="width: 100%; height: auto;" />
                            </div>
                        </foreignObject>
                        <g transform="translate(${marginLeft}, ${marginTop + scaledHeight})">
                            ${svg}s
                        </g>
                    </svg>
            `;

            const blob = new Blob([combinedSVG], { type: "image/svg+xml;charset=utf-8" });
            const url = URL.createObjectURL(blob);

            const link = document.createElement("a");
            link.href = url;
            link.download = "combined-exported-content.svg";
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);

            URL.revokeObjectURL(url);
        },

        loadImage(src: string): Promise<HTMLImageElement> {
            return new Promise((resolve, reject) => {
                const img = new Image();
                img.src = src;
                img.onload = () => resolve(img);
                img.onerror = (error) => reject(error);
            });
        },
    },
});
</script>
