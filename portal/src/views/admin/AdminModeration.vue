<template>
    <StandardLayout>
        <div class="container">
            <router-link :to="{ name: 'adminMain' }" class="link">{{ $t("admin.backBtn") }}</router-link>

            <div class="busy" v-if="busy">{{ $t("loading") }}</div>

            <div v-if="!busy">
                <PaginationControls :page="page" :totalPages="totalPages" @new-page="onNewPage" />
            </div>

            <table class="stations" v-if="!busy">
                <thead>
                    <tr class="header">
                        <th>ID</th>
                        <th>Post ID</th>
                        <th>Post Type</th>
                        <th>Reported by</th>
                        <th>Acknowledged by</th>
                        <th>Is Acknowledged</th>
                        <th>Reported at</th>
                        <th>Acknowledged at</th>
                        <th></th>
                    </tr>
                </thead>
            </table>

            <div v-if="!busy">
                <PaginationControls :page="page" :totalPages="totalPages" @new-page="onNewPage" />
            </div>
        </div>
    </StandardLayout>
</template>

<script lang="ts">
import Vue from "vue";
import StandardLayout from "../StandardLayout.vue";
import CommonComponents from "@/views/shared";
import PaginationControls from "@/views/shared/PaginationControls.vue";

export default Vue.extend({
    name: "AdminModeration",
    components: {
        ...CommonComponents,
        StandardLayout,
        PaginationControls,
    },
    props: {
        page: {
            type: Number,
            default: 0,
        },
    },
    data(): {
        posts: any[];
        pageSize: number;
        totalPages: number;
        busy: boolean;
    } {
        return {
            posts: [],
            pageSize: 50,
            totalPages: 0,
            busy: false,
        };
    },
    mounted(this: any) {
      console.log("mounted admin moderation");
    },
    watch: {},
    methods: {
        onNewPage(page: number) {
            window.scrollTo(0, 0);
            this.$router.push({
                name: "adminModeration",
                query: { page: `${page}` },
            });
        },
    },
});
</script>

<style scoped>
.container {
    display: flex;
    flex-direction: column;
    padding: 20px;
    text-align: left;
}

.stations {
    font-size: 15px;
    margin-top: 1em;
}
.stations thead tr th {
    background-color: #fcfcfc;
    border-bottom: 2px solid var(--color-border);
}
.stations tbody tr {
    padding: 5px;
}
.stations td {
    padding: 2px;
}
.stations .date {
    text-align: right;
}
.stations .button {
    font-size: 12px;
    padding: 5px;
    background-color: #ffffff;
    border: 1px solid rgb(215, 220, 225);
    border-radius: 4px;
    cursor: pointer;
    text-align: center;
}

.row {
    display: flex;
    flex-direction: row;
    justify-content: space-between;
}
</style>
