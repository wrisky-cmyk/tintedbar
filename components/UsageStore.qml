pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: store

    property var usage: ({})
    property bool loaded: false
    property bool pendingSave: false

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Style.home + "/.local/state")) + "/quickshell"

    function bump(key) {
        const k = String(key || "");
        if (k === "")
            return;
        const u = Object.assign({}, store.usage);
        u[k] = (u[k] || 0) + 1;
        store.usage = u;
        store.pendingSave = true;
        saveDebounce.restart();
    }

    Process {
        id: usageLoad
        running: true
        command: ["sh", "-c", Style.readJsonCmd(store.stateDir + "/launcher-usage.json", "{}")]
        stdout: StdioCollector {
            onStreamFinished: {
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
                    saveDebounce.restart();
                }
            }
        }
    }

    Process {
        id: usageSave
        running: false

        onExited: code => {
            if (code !== 0)
                console.warn("[USAGE] usage save failed rc=" + code);
        }
    }

    Timer {
        id: saveDebounce
        interval: 200
        onTriggered: {
            if (!store.loaded)
                return;
            if (usageSave.running) {
                restart();
                return;
            }
            usageSave.command = ["sh", "-c", Style.atomicWriteCmd(store.stateDir + "/launcher-usage.json", JSON.stringify(store.usage))];
            usageSave.running = true;
        }
    }
}
