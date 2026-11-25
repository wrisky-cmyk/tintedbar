import QtQuick
import Quickshell.Io

Item {
    id: store

    required property string path

    property string defaultText: "{}"

    property var serialize: null

    property int debounceMs: 200

    property int consecutiveFailures: 0

    property int maxAutoRetries: 3
    property string debounceMode: "restart"
    property int retryLimit: 0
    property int retryIntervalMs: 1000
    property bool loadOnStart: true

    property bool loaded: false

    property string pendingLoadText: ""

    property bool dirty: false

    property int failures: 0

    signal textLoaded(string text)
    signal saveFailed(int code, int failures)
    signal saved

    signal loadFailed(string path, int code)

    property bool loadBlocked: false

    Component.onCompleted: if (store.loadOnStart)
        store.load()

    function load() {
        if (loadProc.running)
            return;
        loadProc.running = true;
    }

    function requestSave() {
        if (!store.serialize)
            return;
        store.dirty = true;

        store.consecutiveFailures = 0;
        store.reschedule();
    }

    function reschedule() {
        if (!store.dirty || !store.loaded)
            return;
        if (store.debounceMs <= 0) {
            store.flush();
            return;
        }
        if (store.debounceMode === "tick") {
            if (!debounce.running)
                debounce.start();
        } else {
            debounce.restart();
        }
    }

    function flush() {
        if (store.loadBlocked) {
            store.dirty = false;
            return;
        }
        if (!store.loaded || !store.dirty || saveProc.running || !store.serialize)
            return;
        let json = "";
        try {
            json = String(store.serialize());
        } catch (e) {
            console.warn("[JSONSTORE] serialize failed for " + store.path + ": " + e);
            return;
        }
        store.dirty = false;
        saveProc.payload = json;
        saveProc.command = ["bash", Style.configDir + "/scripts/atomic-write.sh", store.path];
        saveProc.stdinEnabled = true;
        saveProc.running = true;
    }

    Process {
        id: loadProc
        running: false
        command: ["sh", "-c", Style.readJsonCmd(store.path, store.defaultText)]

        stdout: StdioCollector {
            onStreamFinished: store.pendingLoadText = text
        }

        onExited: code => {
            if (code === 3) {
                store.loadBlocked = true;
                store.pendingLoadText = "";
                store.dirty = false;
                store.loaded = true;
                console.warn("[JSONSTORE] cannot read " + store.path + " (exists but unreadable, exit " + code + "); write-back disabled");
                store.loadFailed(store.path, code);
                return;
            }
            if (store.loaded)
                return;
            if (code !== 0) {
                console.warn("[JSONSTORE] load failed for " + store.path + " (exit " + code + ")");
                store.textLoaded("");
            } else {
                store.textLoaded(store.pendingLoadText);
            }
            store.loaded = true;
            if (store.dirty)
                store.reschedule();
        }
    }

    Process {
        id: saveProc
        running: false
        stdinEnabled: true
        property string payload: ""
        onStarted: {
            saveProc.write(saveProc.payload);
            saveProc.stdinEnabled = false;
        }
        onExited: code => {
            if (code === 0) {
                store.failures = 0;
                store.consecutiveFailures = 0;
                retryTimer.stop();
                store.saved();
            } else {
                store.failures++;
                store.consecutiveFailures++;
                store.saveFailed(code, store.failures);
                if (store.retryLimit > 0 && store.failures <= store.retryLimit)
                    retryTimer.restart();
                else
                    store.dirty = true;
            }

            if (store.dirty) {
                const capped = store.maxAutoRetries > 0 && store.consecutiveFailures >= store.maxAutoRetries;
                if (!capped)
                    store.reschedule();
            }
        }
    }

    Timer {
        id: debounce

        interval: Math.max(1, store.debounceMs)
        repeat: store.debounceMode === "tick"
        onTriggered: {
            if (!store.dirty) {
                stop();
                return;
            }
            store.flush();

            if (store.debounceMode === "tick" && !store.dirty)
                stop();
        }
    }

    Timer {
        id: retryTimer
        interval: Math.max(1, store.retryIntervalMs)
        repeat: false
        onTriggered: {
            if (!store.dirty)
                store.dirty = true;

            if (store.maxAutoRetries > 0 && store.consecutiveFailures >= store.maxAutoRetries)
                return;
            store.reschedule();
        }
    }
}
