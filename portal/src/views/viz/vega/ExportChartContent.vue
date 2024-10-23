<template>
    <div class="export-chart-content" id="export-chart-content">
        <div class="project-detail-wrap" v-if="project">
            <div class="project-detail-card">
                <div
                    id="exported-project-photo"
                    class="photo-container"
                    :style="{ backgroundImage: `url(${projectPhoto})`, backgroundSize: 'cover', backgroundPosition: 'center' }"
                >
                    <ProjectPhoto :project="project" :image-size="132" @project-photo-loaded="onProjectPhotoLoaded($event)" />
                </div>
                <div class="detail-container">
                    <div>
                        <div class="flex flex-al-center">
                            <h1 class="detail-title">{{ project.name }}</h1>
                        </div>
                        <div class="detail-description">{{ project.description }}</div>
                    </div>
                </div>
            </div>
        </div>

        <div class="viz-stations">
            <div class="viz-station-row" v-for="(item, index) in stationSensorPairs" :key="index">
                <div class="tree-key" :style="{ color: getKeyColor(index) }">&#9632;</div>
                <span>{{ item.stationName }}:</span>
                <span>{{ item.sensorName }}</span>
            </div>
            <i v-if="!isCustomisationEnabled()" id="header-logo" class="icon icon-logo-fieldkit"></i>
        </div>
    </div>
</template>

<script lang="ts">
import Vue from "vue";
import ProjectPhoto from "@/views/shared/ProjectPhoto.vue";
import { getPartnerCustomization, isCustomisationEnabled } from "@/views/shared/partners";
import { Project } from "@/api";
import chartStyles from "@/views/viz/vega/chartStyles";

export default Vue.extend({
    name: "ExportChartContent",
    components: { ProjectPhoto },
    data(): {
        project: Project | null;
        projectPhoto: string | null;
    } {
        return {
            project: null,
            projectPhoto: null,
        };
    },
    methods: {
        isCustomisationEnabled,
        getKeyColor(idx: string | number) {
            const color = idx === 0 ? chartStyles.primaryLine.stroke : chartStyles.secondaryLine.stroke;
            return color;
        },
        onProjectPhotoLoaded(photo: string) {
            this.projectPhoto = photo;
        },
    },
    computed: {
        stationSensorPairs() {
            return this.$store.getters.getAllVizStationsAndSensors;
        },
    },
    mounted() {
        const partnerCustomization = getPartnerCustomization();
        if (partnerCustomization && partnerCustomization.projectId === 174) {
            this.$services.api.getProject(partnerCustomization.projectId).then((project) => {
                this.project = project;
            });
        }
    },
});
</script>

<style scoped lang="scss">
@import "src/scss/project-detail-card.scss";

.export-chart-content {
    position: absolute;
    left: -10000px;
    width: 100%;
    overflow: hidden;
    text-align: left;
    background: #fff;

    .project-photo {
        visibility: hidden;
    }

    .project-detail-card {
        background: #fff !important;
        align-items: center;
        border-right: none;
        position: unset;
    }

    .detail-title {
        margin-bottom: 5px;
    }

    .photo-container {
        height: 66px;
        flex: 0 0 66px;
        background-size: cover;
        background-position: center;
        background-repeat: no-repeat;
    }
}

.project-detail-wrap {
    position: relative;

    .icon-logo-fieldkit {
        position: absolute;
        top: 50%;
        transform: translateY(-50%);
        right: 30px;
        font-size: 26px;
    }
}

.viz-stations {
    padding: 32px 48px 16px;
    border-bottom: 1px solid $color-border;
    position: relative;

    .icon-logo-fieldkit {
        font-size: 32px;
        position: absolute;
        right: 48px;
        top: 50%;
        transform: translateY(-50%);
    }
}

.viz-station-row {
    font-size: 16px;
    margin-bottom: 16px;
    display: flex;
    align-items: center;

    span:nth-of-type(1) {
        font-family: $font-family-bold;
        margin-right: 5px;
    }
}
</style>
