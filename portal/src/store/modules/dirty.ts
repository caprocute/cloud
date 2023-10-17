import * as ActionTypes from '@/store/actions';
import {FieldNotesState} from '@/store';
import Vue from 'vue';

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
            {commit, dispatch, state}: { commit: any; dispatch: any; state: FieldNotesState },
            payload: string
        ) => {
            commit("ADD_DIRTY_FIELD", payload);
        },
        [ActionTypes.CLEAR_DIRTY_FIELDS]: async (
            {commit, dispatch, state}: { commit: any; dispatch: any; state: FieldNotesState },
            payload: string
        ) => {
            commit("CLEAR_DIRTY_FIELDS");
        },
    };
};

const mutations = {
    ["ADD_DIRTY_FIELD"]: (
        state: DirtyState,
        payload: string,
    ) => {
        if (!state.dirtyInputs.includes(payload)) {
            const updatedState = state.dirtyInputs.push(payload);
            Vue.set(state, "busy", updatedState);
        }
    },
    ["CLEAR_DIRTY_FIELDS"]: (
        state: DirtyState,
    ) => {
        Vue.set(state, "busy", {dirtyInputs: []});
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
