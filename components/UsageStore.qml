pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: store

    property var usage: ({})
    property bool loaded: false
    property bool pendingSave: false

    readonly property string stateDir: Style.stateDir

    function bump(key) {
        const k = String(key || "");
        if (k === "")
            return;
        const u = Object.assign({}, store.usage);
        u[k] = (u[k] || 0) + 1;
        store.usage = u;
        store.pendingSave = true;
        jsonStore.requestSave();
    }

    JsonStore {
        id: jsonStore
        path: Style.stateDir + "/launcher-usage.json"
        defaultText: "{}"
        serialize: () => JSON.stringify(store.usage)
        onTextLoaded: text => {
            let loaded = {};
            try {
                loaded = JSON.parse(String(text));
            } catch (e) {
                loaded = {};
            }
            if (!loaded || typeof loaded !== "object" || Array.isArray(loaded))
                loaded = {};
            const merged = Object.assign({}, loaded);
            for (const k in store.usage)
                merged[k] = Math.max(merged[k] || 0, store.usage[k] || 0);
            store.usage = merged;
            store.loaded = true;
            if (store.pendingSave) {
                store.pendingSave = false;
                requestSave();
            }
        }
    }
}
