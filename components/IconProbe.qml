pragma Singleton

import QtQuick
import Quickshell.Io

Item {
    id: root

    property var iconCache: ({})

    function iconCacheGet(key) {
        return (key in root.iconCache) ? root.iconCache[key] : undefined;
    }

    function iconCacheSet(key, path) {
        root.iconCache[key] = path;
        if (root._iconProbeRetries[key] !== undefined)
            delete root._iconProbeRetries[key];
    }

    signal iconProbesFinished
    property var _iconQueue: ({})
    property var _iconProbePending: []

    property int _iconProbeGen: 0
    property int _iconProbeBatchGen: 0

    property var _iconProbeRetries: ({})

    Timer {
        id: iconProbeFlush
        interval: 50
        onTriggered: root.flushIconProbeQueue()
    }

    property var _loginRetryWatch: []
    Timer {
        id: loginMissRetry
        interval: 15000
        repeat: false
        running: true
        onTriggered: {
            const retry = {};
            let n = 0;
            for (const k in root.iconCache) {
                const names = root.iconProbeNamesForKey(k);
                if (root.iconCache[k] === "" && names !== undefined) {
                    retry[k] = names;
                    n++;
                }
            }

            for (const k of root._iconProbePending) {
                const names = root.iconProbeNamesForKey(k);
                if (names !== undefined && root._loginRetryWatch.indexOf(k) < 0)
                    root._loginRetryWatch.push(k);
            }
            if (n === 0 && root._loginRetryWatch.length === 0)
                return;
            console.log("[ICONPROBE] login MISS retry: " + n + " keys requeued, watching " + root._loginRetryWatch.length + " in-flight");
            for (const k in retry)
                delete root.iconCache[k];

            for (const k in retry)
                if (root._iconQueue[k] === undefined)
                    root._iconQueue[k] = retry[k];
            iconProbeFlush.restart();
        }
    }

    Process {
        id: iconProbeProc
        running: false
        onStarted: iconProbeWatchdog.restart()
        onExited: {
            iconProbeWatchdog.stop();

            if (root._iconProbePending.length > 0)
                root.iconProbeBatchDone("");
        }
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.iconProbeBatchDone(text)
        }
    }

    Timer {
        id: iconProbeWatchdog
        interval: 5000
        repeat: false
        onTriggered: {
            if (!iconProbeProc.running)
                return;
            console.warn("[ICONPROBE] batch watchdog expired, killing stuck process");
            iconProbeProc.running = false;
        }
    }

    function iconProbeNamesForKey(key) {
        try {
            const names = JSON.parse(key);
            if (Array.isArray(names) && names.length > 0)
                return names;
        } catch (e) {
            console.warn("[ICONPROBE] failed to parse candidate key: " + e);
        }
        return undefined;
    }

    function requestIconProbe(key, names) {
        if (root.iconCacheGet(key) !== undefined)
            return;
        if (root._iconQueue[key])
            return;
        root._iconQueue[key] = names;
        iconProbeFlush.restart();
    }

    function flushIconProbeQueue() {
        if (iconProbeProc.running) {
            iconProbeFlush.restart();
            return;
        }
        const queue = root._iconQueue;
        const keys = Object.keys(queue);
        if (keys.length === 0)
            return;
        root._iconQueue = {};
        root._iconProbeBatchGen = root._iconProbeGen;

        let s = ". " + Style.sq(Style.configDir + "/scripts/icon-probe-lib.sh") + "\n";
        s += "probe() {\n";
        s += "  for n in \"$@\"; do\n";
        s += "    try_name \"$n\" && return 0\n";
        s += "  done\n";
        s += "  return 1\n";
        s += "}\n";
        const batchKeys = [];

        for (let i = 0; i < keys.length; i++) {
            const k = keys[i];
            let names = "";
            for (const n of queue[k])
                names += " " + Style.sq(n);
            let line = "p=\"$(probe" + names + ")\"\n";
            line += "printf '%s\\037%s\\n' " + Style.sq(k) + " \"$p\"\n";
            if (batchKeys.length > 0 && s.length + line.length > 60000) {
                for (let j = i; j < keys.length; j++)
                    root._iconQueue[keys[j]] = queue[keys[j]];
                break;
            }
            s += line;
            batchKeys.push(k);
        }
        if (batchKeys.length === 0) {
            root._iconQueue = queue;
            return;
        }
        root._iconProbePending = batchKeys;
        s += "printf 'DONE\\n'\n";
        iconProbeProc.command = ["sh", "-c", s];
        iconProbeProc.running = true;
        iconProbeWatchdog.restart();
    }

    function iconProbeBatchDone(text) {
        const stale = root._iconProbeBatchGen !== root._iconProbeGen;

        const watchLanded = (key, missed) => {
            const wi = root._loginRetryWatch.indexOf(key);
            if (wi < 0)
                return;
            root._loginRetryWatch.splice(wi, 1);
            if (missed) {
                const names = root.iconProbeNamesForKey(key);
                if (names !== undefined) {
                    delete root.iconCache[key];
                    root._iconQueue[key] = names;
                    iconProbeFlush.restart();
                }
            }
        };
        let sawDone = false;
        if (!stale) {
            for (const line of String(text).split("\n")) {
                if (line === "")
                    continue;
                if (line === "DONE") {
                    sawDone = true;
                    continue;
                }
                const sep = line.indexOf("\u001f");
                if (sep < 0)
                    continue;
                const key = line.substring(0, sep);
                const path = line.substring(sep + 1).trim();
                if (key in root.iconCache)
                    continue;
                root.iconCacheSet(key, path);
            }

            for (const k of root._iconProbePending) {
                const landed = root.iconCacheGet(k);
                if (landed === undefined) {
                    if (sawDone) {
                        watchLanded(k, false);
                        root.iconCacheSet(k, "");
                    } else {
                        watchLanded(k, false);
                        const names = root.iconProbeNamesForKey(k);
                        const tries = Number(root._iconProbeRetries[k] || 0) + 1;
                        root._iconProbeRetries[k] = tries;
                        if (names !== undefined && tries <= 2) {
                            root._iconQueue[k] = names;
                            iconProbeFlush.restart();
                        } else {
                            root.iconCacheSet(k, "");
                            console.warn("[ICONPROBE] no stdout after retries, marking MISS: " + k);
                        }
                    }
                } else {
                    watchLanded(k, landed === "");
                }
            }
        } else {
            root._loginRetryWatch = [];
        }
        iconProbeWatchdog.stop();
        root._iconProbePending = [];
        root.iconProbesFinished();
    }
}
