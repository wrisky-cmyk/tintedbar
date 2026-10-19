pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: store

    property var usage: ({})

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Style.home + "/.local/state")) + "/quickshell"

    function bump(key) {
        const k = String(key || "");
        if (k === "")
            return;
        const u = Object.assign({}, store.usage);
        u[k] = (u[k] || 0) + 1;
        store.usage = u;
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
                const merged = Object.assign({}, loaded);
                for (const k in store.usage)
                    merged[k] = Math.max(merged[k] || 0, store.usage[k] || 0);
                store.usage = merged;
            }
        }
    }

    Process {
        id: usageSave
        running: false
    }

    Timer {
        id: saveDebounce
        interval: 200
        onTriggered: {
            if (usageSave.running) {
                restart();
                return;
            }
            usageSave.command = ["sh", "-c", Style.atomicWriteCmd(store.stateDir + "/launcher-usage.json", JSON.stringify(store.usage))];
            usageSave.running = true;
        }
    }
}
