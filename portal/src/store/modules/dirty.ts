import * as ActionTypes from "@/store/actions";
import Vue from "vue";

export class DirtyState {
    dirtyInputs: string[] = [];
}

const getters = {
    dirtyInputs(state: DirtyState): string[] {
        return state.dirtyInputs;
    },
};

const actions = () => {
    return {
        [ActionTypes.NEW_DIRTY_FIELD]: async (
            { commit, dispatch, state }: { commit: any; dispatch: any; state: DirtyState },
            payload: string
        ) => {
            commit("ADD_DIRTY_FIELD", payload);
        },
        [ActionTypes.CLEAR_DIRTY_FIELD]: async (
            { commit, dispatch, state }: { commit: any; dispatch: any; state: DirtyState },
            payload: string
        ) => {
            commit("CLEAR_DIRTY_FIELD", payload);
        },
        [ActionTypes.CLEAR_ALL_DIRTY_FIELDS]: async (
            { commit, dispatch, state }: { commit: any; dispatch: any; state: DirtyState },
            payload: string
        ) => {
            commit("CLEAR_ALL_DIRTY_FIELDS");
        },
    };
};

const mutations = {
    ["ADD_DIRTY_FIELD"]: (state: DirtyState, payload: string) => {
        if (!state.dirtyInputs.includes(payload)) {
            const updatedState = state.dirtyInputs.push(payload);
            Vue.set(state, "", updatedState);
        }
    },
    ["CLEAR_DIRTY_FIELD"]: (state: DirtyState, payload: string) => {
        const newState = state.dirtyInputs.filter((input) => input !== payload);
        console.log("new state", newState);
        Vue.set(state, "dirtyInputs", newState);
    },
    ["CLEAR_ALL_DIRTY_FIELDS"]: (state: DirtyState) => {
        Vue.set(state, "dirtyInputs", []);
    },
};

export const dirty = () => {
    const state = () => new DirtyState();

    return {
        namespaced: false,
        state,
        getters,
        actions: actions(),
        mutations,
    };
};

export function confirmLeaveWithDirtyCheck(
    callback: () => void,
    component: Vue & { $confirm(message: string, options: any): void; $store: { state: { dirty: DirtyState } } }
) {
    const { dirtyInputs } = component.$store.state.dirty;
    if (dirtyInputs.length > 0) {
        component.$confirm({
            message: component.$tc("notes.confirmLeavePopupMessage"),
            button: {
                no: component.$tc("no"),
                yes: component.$tc("yes"),
            },
            callback: (confirm: boolean) => {
                if (confirm) {
                    component.$store.dispatch(ActionTypes.CLEAR_ALL_DIRTY_FIELDS);
                    callback();
                }
            },
        });
    } else {
        callback();
    }
}
