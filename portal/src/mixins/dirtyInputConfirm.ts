import {ActionTypes} from '@/store';
import Vue from "vue";

export default {
    methods: {

        confirmDirtyInputLeave() {
            console.log("radoi");
        }

      /*  confirmDirtyInputLeave(): Promise<boolean> {

            const dirtyInputs = this.$store.state.dirty.dirtyInputs;

            console.log("radoi merge", dirtyInputs);

            return new Promise((resolve) => {
                if (dirtyInputs.length) {
                    this.$confirm({
                        message: this.$tc("notes.confirmLeavePopupMessage"),
                        button: {
                            no: this.$tc("no"),
                            yes: this.$tc("yes"),
                        },
                        callback: async (confirm) => {
                            if (confirm) {
                                await this.$store.dispatch(ActionTypes.CLEAR_DIRTY_FIELDS);
                                resolve(true);
                            }
                            resolve(false);
                        },
                    });
                } else {
                    resolve(true);
                }
            });
        },*/
    },
};
