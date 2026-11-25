pragma Singleton

import QtQuick
import Quickshell.Io

Item {
    id: store

    property var usage: ({})
    property bool loaded: false
    property bool pendingSave: false

    property bool usageLoadCorrupt: false

    readonly property string stateDir: Style.stateDir

    function bump(key) {
        const k = String(key || "");
        if (k === "")
            return;

        if (store.usageLoadCorrupt)
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
            let saved = {};
            let parseOk = true;
            try {
                saved = JSON.parse(String(text));
            } catch (e) {
                parseOk = false;
            }

            if (!saved || typeof saved !== "object" || Array.isArray(saved)) {
                saved = {};

                if (text.trim() !== "" && text.trim() !== "{}")
                    parseOk = false;
            }
            if (!parseOk) {
                console.warn("[USAGE] launcher-usage.json is corrupt; quarantining as .corrupt");
                store.usageLoadCorrupt = true;
                usageQuarantine.running = true;

                return;
            }
            const loaded = saved;
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

    Process {
        id: usageQuarantine
        running: false
        command: ["sh", "-c", "mv -f " + Style.sq(store.stateDir + "/launcher-usage.json") + " " + Style.sq(store.stateDir + "/launcher-usage.json.corrupt")]
        onExited: code => {
            if (code !== 0) {
                console.warn("[USAGE] could not quarantine corrupt usage file, exit " + code + "; write-back stays disabled");
                return;
            }
            store.usageLoadCorrupt = false;
            store.usage = ({});
            store.loaded = true;
            console.warn("[USAGE] corrupt usage file quarantined as .corrupt; starting fresh");
            if (store.pendingSave) {
                store.pendingSave = false;
                jsonStore.requestSave();
            }
        }
    }
}
