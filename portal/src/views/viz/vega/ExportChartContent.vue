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

        <div class="viz-stations" :class="{ 'has-logo': !isCustomisationEnabled() }">
            <div class="viz-station-row" v-for="(item, index) in typedStationSensorPairs" :key="index">
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
import { PropType } from "vue";

export default Vue.extend({
    name: "ExportChartContent",
    components: { ProjectPhoto },
    props: {
        stationSensorPairs: {
            type: Array,
            default: () => [],
        },
        project: {
            type: Object as PropType<Project>,
            default: null,
        },
    },
    data(): {
        projectPhoto: string | null;
    } {
        return {
            projectPhoto: null,
        };
    },
    computed: {
        typedStationSensorPairs(): { stationName: string; sensorName: string }[] {
            return this.stationSensorPairs as { stationName: string; sensorName: string }[];
        },
    },
    methods: {
        isCustomisationEnabled,
        getKeyColor(idx: number): string {
            const color = idx === 0 ? chartStyles.primaryLine.stroke : chartStyles.secondaryLine.stroke;
            return color;
        },
        onProjectPhotoLoaded(photo: string) {
            this.projectPhoto = photo;
        },
    },
});
</script>

<style scoped lang="scss">
@use "src/scss/project-detail-card.scss";
@use "src/scss/variables";

.export-chart-content {
    position: absolute;
    left: -10000px;
    width: 1080px;
    overflow: hidden;
    text-align: left;
    background: #fff;

    // Use full width for mobile exports
    @media (max-width: 768px) {
        width: 100%;
    }

    .project-photo {
        visibility: hidden;
    }

    .project-detail-card {
        background: #fff !important;
        align-items: center;
        border-right: none;
        position: unset;

        // Consistent padding with viz-stations on mobile
        @media (max-width: 768px) {
            padding: 20px 20px;
        }
    }

    .detail-title {
        margin-bottom: 5px;
        font-size: 18px;
    }

    .detail-description {
        font-size: 12px;
    }

    .photo-container {
        height: 50px;
        flex: 0 0 50px;
        background-size: cover;
        background-position: center;
        background-repeat: no-repeat;
    }
}

.project-detail-wrap {
    position: relative;
    width: 100%;

    .icon-logo-fieldkit {
        position: absolute;
        top: 50%;
        transform: translateY(-50%);
        right: 30px;
        font-size: 20px;
    }
}

.viz-stations {
    padding: 20px 44px 6px;
    border-bottom: 1px solid variables.$color-border;
    position: relative;

    // Match project header padding on mobile
    @media (max-width: 768px) {
        padding: 20px 20px 6px;
    }

    // When logo is present (customization disabled), remove bottom padding
    // so logo centers properly relative to station text
    &.has-logo {
        padding-bottom: 0;
    }

    .icon-logo-fieldkit {
        font-size: 24px;
        position: absolute;
        right: 48px;
        top: 50%;
        transform: translateY(-50%);

        @media (max-width: 768px) {
            right: 20px;
        }
    }
}

.viz-station-row {
    font-size: 12px;
    margin-bottom: 16px;
    display: flex;
    align-items: center;

    span:nth-of-type(1) {
        font-family: variables.$font-family-bold;
        margin-right: 5px;
    }
}

.tree-key {
    margin-top: -4px;
}
</style>
