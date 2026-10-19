pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "."

Item {
    id: wm

    property var entries: ({})

    readonly property string home: Quickshell.env("HOME") || ""

    readonly property string confPath: Style.configDir + "/wallpapers.conf"

    function pathFor(screenName) {
        const hit = wm.resolve(screenName);
        return hit ? hit.path : "";
    }
    function modeFor(screenName) {
        const hit = wm.resolve(screenName);
        return hit && hit.mode ? hit.mode : "cover";
    }

    function colorFor(screenName) {
        const hit = wm.resolve(screenName);
        return hit && hit.color ? hit.color : "";
    }
    function resolve(screenName) {
        const name = String(screenName === undefined ? "" : screenName);
        return wm.entries[name] || wm.entries["*"] || null;
    }

    function summary() {
        const out = [];
        for (const k of Object.keys(wm.entries).sort()) {
            const e = wm.entries[k];
            out.push(k + "=" + (e.path !== "" ? e.path : (e.color !== "" ? e.color + "(纯色)" : "(空)")));
        }
        return out.join("  ");
    }

    function expandPath(p) {
        const s = String(p === undefined ? "" : p).trim();
        return s.startsWith("~") ? wm.home + s.slice(1) : s;
    }

    function absorb(text) {
        wm.entries = wm.parseConf(text);
        console.log("[WALLPAPER] 映射: " + wm.summary());
    }

    function reload() {
        conf.reload();
    }

    function isColor(v) {
        return /^(?:color:)?#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/.test(v);
    }
    function normColor(v) {
        return String(v).replace(/^color:/i, "");
    }

    function parseConf(text) {
        const out = {};
        for (const raw of String(text === undefined ? "" : text).split("\n")) {
            if (/^\s*#/.test(raw))
                continue;
            const line = raw.trim();
            const eq = line.indexOf("=");
            if (eq <= 0)
                continue;
            const key = line.slice(0, eq).trim();
            let val = line.slice(eq + 1).trim();

            if (!wm.isColor(val)) {
                const ci = val.search(/\s#/);
                if (ci >= 0)
                    val = val.slice(0, ci).trim();
            }
            if (wm.isColor(val)) {
                out[key] = {
                    path: "",
                    mode: "cover",
                    color: wm.normColor(val)
                };
                continue;
            }
            let mode = "cover";
            const bar = val.lastIndexOf("|");
            if (bar > 0 && /^(cover|contain|tile)$/.test(val.slice(bar + 1).trim())) {
                mode = val.slice(bar + 1).trim();
                val = val.slice(0, bar).trim();
            }
            out[key] = {
                path: wm.expandPath(val),
                mode: mode,
                color: ""
            };
        }
        return out;
    }

    FileView {
        id: conf
        path: wm.confPath
        blockLoading: true
        preload: true
        printErrors: false
        watchChanges: true
        onLoaded: wm.absorb(text())

        onFileChanged: wm.reload()
    }
}
