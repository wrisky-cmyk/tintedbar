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
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.iconProbeBatchDone(text)
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
        root._iconProbePending = keys;
        root._iconProbeBatchGen = root._iconProbeGen;
        let s = root.iconProbeFunc();
        s += "probe() {\n";
        s += "  for n in \"$@\"; do\n";
        s += "    try_name \"$n\" && return 0\n";
        s += "  done\n";
        s += "  return 1\n";
        s += "}\n";
        for (const k of keys) {
            let names = "";
            for (const n of queue[k])
                names += " " + Style.sq(n);

            s += "p=\"$(probe" + names + ")\"\n";
            s += "printf '%s\\037%s\\n' " + Style.sq(k) + " \"$p\"\n";
        }
        s += "printf 'DONE\\n'\n";
        iconProbeProc.command = ["sh", "-c", s];
        iconProbeProc.running = true;
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
        root._iconProbePending = [];
        root.iconProbesFinished();
    }

    function iconProbeFunc() {
        let s = "";
        s += "t=\"$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null";

        s += " | sed -n \"s/^'//;s/'$//p\")\"\n";
        s += "[ -n \"$t\" ] || t=\"$(sed -n 's/^gtk-icon-theme-name=//p'";
        s += " \"$HOME/.config/gtk-3.0/settings.ini\" 2>/dev/null)\"\n";
        s += "[ -n \"$t\" ] || t=hicolor\n";

        s += "CHAIN=\"\"\n";
        s += "for base in \"$HOME/.local/share/icons\" /usr/share/icons; do\n";
        s += "  [ -f \"$base/$t/index.theme\" ] && CHAIN=\"$CHAIN";
        s += " $(sed -n 's/^Inherits=//p' \"$base/$t/index.theme\" | tr ',' ' ')\"\n";
        s += "done\n";
        s += "try_name() {\n";
        s += "  n=\"$1\"\n";

        s += "  for th in \"$t\" $CHAIN hicolor Adwaita default; do\n";
        s += "    for base in \"$HOME/.local/share/icons\" /usr/share/icons; do\n";
        s += "      [ -d \"$base/$th\" ] || continue\n";
        s += "      # 不写死尺寸: 直接扫所有尺寸目录(含 512x512、@2x 等)\n";
        s += "      for c in apps actions status devices places categories mimetypes panel; do\n";
        s += "        for f in \"$base/$th\"/*/\"$c\"/\"$n\".svg";
        s += " \"$base/$th\"/*/\"$c\"/\"$n\".png; do\n";
        s += "          [ -f \"$f\" ] && { printf '%s\\n' \"$f\"; exit 0; }\n";
        s += "        done\n";
        s += "      done\n";
        s += "      for c in apps actions status devices places categories emblems; do\n";
        s += "        for f in \"$base/$th\"/*/symbolic/\"$c\"/\"$n\".svg";
        s += " \"$base/$th\"/*/symbolic/\"$c\"/\"$n\".png; do\n";
        s += "          [ -f \"$f\" ] && { printf '%s\\n' \"$f\"; exit 0; }\n";
        s += "        done\n";
        s += "      done\n";
        s += "      for c in apps actions status devices places categories emblems mimetypes; do\n";
        s += "        f=\"$base/$th/symbolic/$c/$n.svg\"\n";
        s += "        [ -f \"$f\" ] && { printf '%s\\n' \"$f\"; exit 0; }\n";
        s += "      done\n";
        s += "    done\n";
        s += "  done\n";
        s += "  for p in /usr/share/pixmaps/$n.svg /usr/share/pixmaps/$n.png";
        s += " /usr/share/pixmaps/$n.xpm; do\n";
        s += "    [ -f \"$p\" ] && { printf '%s\\n' \"$p\"; exit 0; }\n";
        s += "  done\n";
        s += "  return 1\n";
        s += "}\n";
        return s;
    }
}
