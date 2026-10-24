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
    }

    signal iconProbesFinished
    property var _iconQueue: ({})
    property var _iconProbePending: []

    property int _iconProbeGen: 0
    property int _iconProbeBatchGen: 0

    Timer {
        id: iconProbeFlush
        interval: 50
        onTriggered: root.flushIconProbeQueue()
    }

    Process {
        id: iconProbeProc
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.iconProbeBatchDone(text)
        }
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
        iconProbeProc.command = ["sh", "-c", s];
        iconProbeProc.running = true;
    }

    function iconProbeBatchDone(text) {
        const stale = root._iconProbeBatchGen !== root._iconProbeGen;
        if (!stale) {
            for (const line of String(text).split("\n")) {
                if (line === "")
                    continue;
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
                if (root.iconCacheGet(k) === undefined)
                    root.iconCacheSet(k, "");
            }
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
        s += "try_name() {\n";
        s += "  n=\"$1\"\n";

        s += "  ths=\"$t\"\n";
        s += "  for base in \"$HOME/.local/share/icons\" /usr/share/icons; do\n";
        s += "    [ -f \"$base/$t/index.theme\" ] && ths=\"$ths";
        s += " $(sed -n 's/^Inherits=//p' \"$base/$t/index.theme\" | tr ',' ' ')\"\n";
        s += "  done\n";
        s += "  ths=\"$ths hicolor Adwaita default\"\n";
        s += "  for th in $ths; do\n";
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
