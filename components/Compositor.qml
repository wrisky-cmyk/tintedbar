pragma Singleton

import QtQuick
import QtQml
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

Item {
    id: root

    property bool debug: Quickshell.env("QS_DEBUG") === "1"

    readonly property string name: {
        const d = String(Quickshell.env("XDG_CURRENT_DESKTOP") || "").toLowerCase();
        if (d.indexOf("niri") >= 0)
            return "niri";

        if (d.indexOf("hyprland") >= 0)
            return "hyprland";
        if (String(Quickshell.env("NIRI_SOCKET") || "") !== "")
            return "niri";
        return "hyprland";
    }

    property var niriWindows: []
    property var niriWsList: []
    property int niriFocusedIdx: 1

    property string niriFocusedOutput: ""
    property string niriLayout: ""

    property var niriLayoutNames: []

    signal compositorUpdated

    Process {
        id: niriSnapshot
        running: root.name === "niri"
        command: ["sh", "-c", "for i in $(seq 1 50); do [ -S \"$NIRI_SOCKET\" ] && break; sleep 0.2; done; " + "niri msg --json windows && printf '\n--WS--\n' && " + "niri msg --json workspaces && printf '\n--DONE--\n'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let sawComplete = false;
                const stage = {
                    s: "windows"
                };
                for (const line of String(text).split("\n")) {
                    const t = line.trim();
                    if (t === "")
                        continue;
                    if (t === "--WS--") {
                        stage.s = "workspaces";
                        continue;
                    }
                    if (t === "--DONE--") {
                        sawComplete = true;
                        continue;
                    }
                    try {
                        const arr = JSON.parse(t);
                        if (stage.s === "windows")
                            root.applyNiriWindows(arr);
                        else
                            root.applyNiriWorkspaces(arr);
                    } catch (e) {}
                }
                root.compositorUpdated();
                if (!sawComplete && root.name === "niri" && niriSnapshotRetry.retryCount < 3)
                    niriSnapshotRetry.restart();
            }
        }
    }
    Timer {
        id: niriSnapshotRetry
        property int retryCount: 0
        interval: 1500
        onTriggered: {
            retryCount++;
            if (root.name === "niri")
                niriSnapshot.running = true;
        }
    }

    Process {
        id: niriEvents
        running: root.name === "niri"
        command: ["sh", "-c", "for i in $(seq 1 50); do [ -S \"$NIRI_SOCKET\" ] && break; sleep 0.2; done; " + "exec niri msg --json event-stream"]
        stdout: SplitParser {
            onRead: data => root.handleNiriEvent(data)
        }
        onExited: niriEventRetry.restart()
    }
    Timer {
        id: niriEventRetry
        interval: 2000
        onTriggered: if (root.name === "niri" && !niriEvents.running)
            niriEvents.running = true
    }

    function applyNiriWindows(arr) {
        const kept = [];
        for (const w of arr) {
            let e = null;

            const app = String(w.app_id || "");
            for (const old of root.niriWindows)
                if (old.wid === w.id) {
                    e = old;
                    break;
                }
            if (!e) {
                e = {
                    wid: w.id,
                    wsid: w.workspace_id,
                    focused: false,
                    obj: {
                        __wid: w.id,
                        urgent: !!w.is_urgent,
                        class: app,
                        title: String(w.title || ""),
                        wayland: {
                            appId: app
                        },
                        lastIpcObject: {
                            class: app,
                            initialClass: app
                        }
                    }
                };
            } else {
                e.obj.title = String(w.title || "");
                e.obj.class = app;
                e.obj.wayland.appId = app;
                e.obj.lastIpcObject.class = app;
                e.obj.urgent = !!w.is_urgent;
                e.wsid = w.workspace_id;
            }
            e.focused = !!w.is_focused;
            kept.push(e);
        }
        root.niriWindows = kept;
    }

    function applyNiriWorkspaces(arr) {
        const out = [];
        for (const w of arr)
            out.push({
                id: w.id,
                idx: w.idx,
                focused: !!w.is_focused,
                output: String(w.output || "")
            });
        root.niriWsList = out;
        for (const ws of out)
            if (ws.focused) {
                root.niriFocusedIdx = ws.idx;
                root.niriFocusedOutput = ws.output;
            }
    }

    function handleNiriEvent(line) {
        const t = line.trim();
        if (t === "")
            return;
        let ev;
        try {
            ev = JSON.parse(t);
        } catch (e) {
            return;
        }
        const key = Object.keys(ev)[0];
        const v = ev[key];
        if (key === "WorkspacesChanged") {
            root.applyNiriWorkspaces(v.workspaces);
        } else if (key === "WorkspaceActivated") {
            for (const ws of root.niriWsList)
                ws.focused = (ws.id === v.id) && v.focused !== false;

            root.niriWsList = root.niriWsList.slice();
            for (const ws of root.niriWsList)
                if (ws.focused) {
                    root.niriFocusedIdx = ws.idx;
                    root.niriFocusedOutput = ws.output;
                }
        } else if (key === "WindowsChanged") {
            root.applyNiriWindows(v.windows);
        } else if (key === "WindowOpenedOrChanged") {
            const w = v.window;
            const app = String(w.app_id || "");
            let found = null;
            for (const old of root.niriWindows)
                if (old.wid === w.id) {
                    found = old;
                    break;
                }
            if (found) {
                found.obj.title = String(w.title || "");
                found.obj.class = app;
                found.obj.wayland.appId = app;
                found.obj.lastIpcObject.class = app;
                found.obj.urgent = !!w.is_urgent;
                found.wsid = w.workspace_id;
                found.focused = !!w.is_focused;

                root.niriWindows = root.niriWindows.slice();
            } else {
                root.niriWindows = root.niriWindows.concat([
                    {
                        wid: w.id,
                        wsid: w.workspace_id,
                        focused: !!w.is_focused,
                        obj: {
                            __wid: w.id,
                            urgent: !!w.is_urgent,
                            class: app,
                            title: String(w.title || ""),
                            wayland: {
                                appId: app
                            },
                            lastIpcObject: {
                                class: app,
                                initialClass: app
                            }
                        }
                    }
                ]);
            }
        } else if (key === "WindowClosed") {
            const cid = (v.id !== undefined) ? v.id : v.window_id;
            root.niriWindows = root.niriWindows.filter(w => String(w.wid) !== String(cid));
        } else if (key === "WindowFocusChanged") {
            for (const w of root.niriWindows)
                w.focused = (w.wid === v.id);

            root.niriWindows = root.niriWindows.slice();
        } else if (key === "WindowTitleChanged") {
            for (const w of root.niriWindows)
                if (w.wid === v.id)
                    w.obj.title = String(v.title || "");

            root.niriWindows = root.niriWindows.slice();
        } else if (key === "WindowUrgencyChanged") {
            for (const w of root.niriWindows)
                if (String(w.wid) === String(v.id))
                    w.obj.urgent = v.urgent === true;
            root.niriWindows = root.niriWindows.slice();
        } else if (key === "KeyboardLayoutsChanged") {
            const kb = v.keyboard_layouts || {};
            root.niriLayoutNames = kb.names || [];
            root.niriLayout = String(root.niriLayoutNames[kb.current_idx] || "");
        } else if (key === "KeyboardLayoutSwitched") {
            root.niriLayout = String(root.niriLayoutNames[v.idx] || v.idx);
        } else if (key === "ConfigLoaded") {
            return;
        } else {
            return;
        }
        root.compositorUpdated();
    }

    readonly property string activeTitle: root.name === "niri" ? (function () {
            const w = root.niriWindows.find(x => x.focused);
            return w ? w.obj.title : "";
        })() : (function () {
            const t = Hyprland.activeToplevel;
            if (!t)
                return "";
            let wid = -1;
            try {
                if (t.workspace && t.workspace.id !== undefined)
                    wid = t.workspace.id;
                else if (t.lastIpcObject && t.lastIpcObject.workspace && t.lastIpcObject.workspace.id !== undefined)
                    wid = t.lastIpcObject.workspace.id;
            } catch (e) {}
            const ws = wid >= 0 ? root.workspaceForId(wid) : null;
            if (ws && !ws.focused)
                return "";
            return t.title ? String(t.title) : "";
        })()

    function niriWorkspaceFor(outputName, id) {
        for (const ws of root.niriWsList) {
            if (ws.idx !== id)
                continue;
            if (outputName === "" || ws.output === outputName)
                return ws;
        }
        return null;
    }

    function windowsForWorkspace(id, outputName) {
        if (root.name === "niri") {
            const ws = root.niriWorkspaceFor(outputName || root.niriFocusedOutput, id);
            if (!ws)
                return [];
            const out = [];
            for (const w of root.niriWindows)
                if (w.wsid === ws.id)
                    out.push(w.obj);
            return out;
        }
        const ws = root.workspaceForId(id);
        return ws ? root.modelValues(ws.toplevels) : [];
    }

    function workspaceFocused(id, outputName) {
        if (root.name === "niri") {
            if (outputName === "" || root.niriFocusedOutput === "")
                return root.niriFocusedIdx === id;
            return root.niriFocusedOutput === outputName && root.niriFocusedIdx === id;
        }
        const ws = root.workspaceForId(id);
        return ws ? ws.focused : false;
    }

    function setDpms(enable) {
        if (root.name === "niri") {
            Quickshell.execDetached(["niri", "msg", "action", enable ? "power-on-monitors" : "power-off-monitors"]);
            return;
        }

        if (Hyprland.usingLua) {
            Hyprland.dispatch('hl.dsp.dpms("' + (enable ? "on" : "off") + '")');
        } else {
            Hyprland.dispatch("dpms " + (enable ? "on" : "off"));
        }
    }

    function closeWindow() {
        if (root.name === "niri") {
            Quickshell.execDetached(["niri", "msg", "action", "close-window"]);
            return;
        }

        if (Hyprland.usingLua) {
            Hyprland.dispatch("hl.dsp.window.close()");
        } else {
            Hyprland.dispatch("killwindow");
        }
    }

    function activateWorkspace(id, outputName) {
        if (root.name === "niri") {
            if (outputName === "" || outputName === root.niriFocusedOutput) {
                Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", String(id)]);
            } else {
                Quickshell.execDetached(["sh", "-c", "niri msg action focus-monitor " + root.sq(outputName) + " && niri msg action focus-workspace " + root.sq(String(id))]);
            }
            return;
        }
        const ws = root.workspaceForId(id);
        if (ws) {
            ws.activate();
            return;
        }
        if (Hyprland.usingLua) {
            Hyprland.dispatch('hl.dsp.focus({ workspace = "' + root.luaStr(String(id)) + '" })');
        } else {
            Hyprland.dispatch("workspace " + id);
        }
    }

    property string hyprLayout: ""
    Connections {
        target: root.name === "hyprland" ? Hyprland : null
        function onRawEvent(event) {
            if (String(event.name) !== "activelayout")
                return;
            const parts = String(event.data || "").split(",");
            if (parts.length >= 2)
                root.hyprLayout = parts[1];
        }
    }
    function layoutShort() {
        const n = root.name === "niri" ? root.niriLayout : root.hyprLayout;
        if (!n)
            return "";
        const m = String(n).match(/\(([^)]+)\)/);
        return m ? m[1].toLowerCase() : String(n).slice(0, 2).toLowerCase();
    }

    property bool fullscreenActive: {
        const t = ToplevelManager.activeToplevel;
        return t ? t.fullscreen === true : false;
    }

    onFullscreenActiveChanged: console.log("[FS] focused window fullscreen = " + (fullscreenActive ? "yes" : "no"))

    readonly property var appNameAlias: {
        "微信": "wechat",
        "企业微信": "wxwork",
        "QQ音乐": "qqmusic",
        "网易云音乐": "netease-cloud-music-gtk4"
    }

    function candidateKeys(candidates) {
        const keys = [];
        if (!candidates)
            return keys;
        const list = Array.isArray(candidates) ? candidates : [candidates];
        for (const c of list) {
            if (!c)
                continue;
            const s = String(c).toLowerCase();
            if (s !== "" && keys.indexOf(s) < 0)
                keys.push(s);
            const alias = root.appNameAlias[String(c)];
            if (alias && keys.indexOf(alias) < 0)
                keys.push(alias);
        }
        return keys;
    }

    function focusAppWindow(candidates) {
        const keys = root.candidateKeys(candidates);
        if (keys.length === 0)
            return false;
        if (root.debug)
            console.log("[FOCUS] keys=" + JSON.stringify(keys));
        if (root.name === "niri") {
            let hit = null;
            for (const w of root.niriWindows) {
                if (!root.matchKeys(w.obj.class, keys))
                    continue;
                if (w.focused) {
                    hit = w;
                    break;
                }
                if (hit === null)
                    hit = w;
            }
            if (hit === null)
                return false;
            Quickshell.execDetached(["niri", "msg", "action", "focus-window", "--id", String(hit.wid)]);
            return true;
        }

        let best = null;
        let bestCls = "";
        let bestAddr = "";
        for (const ws of root.modelValues(Hyprland.workspaces)) {
            for (const t of root.modelValues(ws.toplevels)) {
                let cls = "";
                try {
                    cls = (t.wayland && t.wayland.appId) ? String(t.wayland.appId) : (t.lastIpcObject ? String(t.lastIpcObject["class"] || "") : "");
                } catch (e) {
                    cls = "";
                }
                if (root.debug)
                    console.log("[FOCUS] scan class=" + cls);
                if (!root.matchKeys(cls, keys))
                    continue;
                best = t;
                bestCls = cls;
                try {
                    bestAddr = t.lastIpcObject ? String(t.lastIpcObject["address"] || "") : "";
                } catch (e) {
                    bestAddr = "";
                }
                break;
            }
            if (best !== null)
                break;
        }
        if (best === null)
            return false;
        if (root.debug)
            console.log("[FOCUS] match class=" + bestCls + " (fallback addr=" + bestAddr + ")");

        fhPickup.keys = keys;
        fhPickup.fallbackCls = bestCls;
        fhPickup.fallbackAddr = bestAddr;
        fhPickup.sentinelToplevel = best;
        fhPickup.sentinelIpc = best.lastIpcObject;
        fhPickup.attempts = 0;
        Hyprland.refreshToplevels();
        fhPickup.restart();
        return true;
    }

    function matchKeys(cls, keys) {
        const c = String(cls || "").toLowerCase();
        if (c === "")
            return false;

        for (const k0 of keys) {
            const k = String(k0 || "").toLowerCase();
            if (c.indexOf(k) >= 0 || k.indexOf(c) >= 0)
                return true;
        }
        return false;
    }

    function toplevelClass(t) {
        try {
            return (t.wayland && t.wayland.appId) ? String(t.wayland.appId) : (t.lastIpcObject ? String(t.lastIpcObject["class"] || "") : "");
        } catch (e) {
            return "";
        }
    }

    function notificationPulseTarget(keys) {
        if (root.name === "hyprland") {
            let best = null;
            let bestFh = 1e9;
            for (const ws of root.modelValues(Hyprland.workspaces)) {
                for (const t of root.modelValues(ws.toplevels)) {
                    if (!root.matchKeys(root.toplevelClass(t), keys))
                        continue;
                    let fh = -1;
                    try {
                        if (t.lastIpcObject && typeof t.lastIpcObject.focusHistoryID === "number")
                            fh = t.lastIpcObject.focusHistoryID;
                    } catch (e) {}
                    if (fh >= 0 && fh < bestFh) {
                        bestFh = fh;
                        best = t;
                    }
                }
            }
            if (root.debug && best)
                console.log("[PULSE] target class=" + root.toplevelClass(best) + " fh=" + bestFh);
            return best;
        }
        if (root.name === "niri") {
            let first = null;
            for (const w of root.niriWindows) {
                if (!root.matchKeys(w.obj.class, keys))
                    continue;
                if (w.focused)
                    return w.obj;
                if (first === null)
                    first = w.obj;
            }
            return first;
        }
        return null;
    }

    signal notificationPulseReady(var keys, bool fresh, var target)
    property var notificationPulseKeys: []
    property bool notificationPulseRefreshing: false
    property var notificationPulseSentinels: []

    function requestNotificationPulse(candidates) {
        const keys = root.candidateKeys(candidates);
        if (keys.length === 0)
            return;
        for (const k of keys)
            if (root.notificationPulseKeys.indexOf(k) < 0)
                root.notificationPulseKeys.push(k);
        if (root.name !== "hyprland") {
            root.finishNotificationPulse(false);
            return;
        }
        if (root.notificationPulseRefreshing)
            return;
        root.notificationPulseRefreshing = true;
        root.notificationPulseSentinels = [];
        for (const ws of root.modelValues(Hyprland.workspaces)) {
            for (const t of root.modelValues(ws.toplevels)) {
                try {
                    if (t && t.lastIpcObject)
                        root.notificationPulseSentinels.push({
                            toplevel: t,
                            ipc: t.lastIpcObject
                        });
                } catch (e) {}
            }
        }
        if (root.debug)
            console.log("[PULSE] refresh keys=" + JSON.stringify(root.notificationPulseKeys));
        Hyprland.refreshToplevels();
        pulseRefreshTimer.attempts = 0;
        pulseRefreshTimer.restart();
    }

    function finishNotificationPulse(fresh) {
        pulseRefreshTimer.stop();
        const keys = root.notificationPulseKeys;

        const target = (root.name === "niri" || fresh) ? root.notificationPulseTarget(keys) : null;
        root.notificationPulseKeys = [];
        root.notificationPulseRefreshing = false;
        root.notificationPulseSentinels = [];
        if (root.debug)
            console.log("[PULSE] ready fresh=" + fresh + " keys=" + JSON.stringify(keys));
        if (keys.length > 0)
            root.notificationPulseReady(keys, fresh, target);
    }

    Timer {
        id: pulseRefreshTimer
        interval: 50
        repeat: true
        property int attempts: 0
        onTriggered: {
            pulseRefreshTimer.attempts++;
            let refreshed = root.notificationPulseSentinels.length > 0;
            for (const pair of root.notificationPulseSentinels) {
                try {
                    if (pair.toplevel.lastIpcObject === pair.ipc) {
                        refreshed = false;
                        break;
                    }
                } catch (e) {}
            }
            if (!refreshed && pulseRefreshTimer.attempts < 10)
                return;
            root.finishNotificationPulse(refreshed);
        }
    }

    Timer {
        id: fhPickup
        interval: 50
        repeat: true
        property var keys: []
        property string fallbackCls: ""
        property string fallbackAddr: ""

        property var sentinelToplevel: null
        property var sentinelIpc: null
        property int attempts: 0
        onTriggered: {
            fhPickup.attempts++;
            let refreshed = false;
            try {
                refreshed = !fhPickup.sentinelToplevel || fhPickup.sentinelToplevel.lastIpcObject !== fhPickup.sentinelIpc;
            } catch (e) {
                refreshed = true;
            }
            if (!refreshed && fhPickup.attempts < 20)
                return;
            fhPickup.stop();
            root.finishFocusPickup(refreshed);
        }
    }

    function finishFocusPickup(refreshed) {
        let cls = "";
        let addr = "";

        if (refreshed) {
            let fh = 1e9;
            for (const ws of root.modelValues(Hyprland.workspaces)) {
                for (const t of root.modelValues(ws.toplevels)) {
                    const o = t.lastIpcObject;
                    if (!o || !root.matchKeys(String(o.class || ""), fhPickup.keys))
                        continue;
                    const v = o.focusHistoryID;
                    const h = (typeof v === "number" && v >= 0) ? v : 1e9;
                    if (addr === "" || h < fh) {
                        cls = String(o.class || "");
                        addr = String(o.address || "");
                        fh = h;
                    }
                }
            }
        }
        if (addr === "" && cls === "") {
            cls = fhPickup.fallbackCls;
            addr = fhPickup.fallbackAddr;
        }
        if (root.debug) {
            console.log("[FOCUS] pickup " + (refreshed ? "refreshed" : "timeout") + " after " + (fhPickup.attempts * fhPickup.interval) + "ms");
        }
        fhPickup.sentinelToplevel = null;
        fhPickup.sentinelIpc = null;
        if (addr === "" && cls === "")
            return;
        root.focusWindowByAddress(cls, addr);
    }

    function focusWindowByAddress(cls, addr) {
        const pattern = addr !== "" ? "address:" + addr : "class:" + cls;

        if (Hyprland.usingLua) {
            Hyprland.dispatch('hl.dsp.focus({ window = "' + root.luaStr(pattern) + '" })');
        } else {
            Hyprland.dispatch("focuswindow " + pattern);
        }
    }

    function modelValues(model) {
        if (!model)
            return [];
        try {
            if (model.values) {
                return typeof model.values === "function" ? model.values() : model.values;
            }
        } catch (e) {}
        const out = [];
        try {
            const n = model.count !== undefined ? model.count : model.length;
            for (let i = 0; i < n; i++) {
                const v = model.get ? model.get(i) : model.objectAt(i);
                if (v)
                    out.push(v);
            }
        } catch (e) {}
        return out;
    }

    function sq(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    function luaStr(s) {
        return String(s).replace(/\\/g, "\\\\").replace(/"/g, "\\\"");
    }

    function workspaceForId(id) {
        for (const w of root.modelValues(Hyprland.workspaces)) {
            if (w && w.id === id)
                return w;
        }
        return null;
    }

    signal rawEvent(var event)
    signal focusedWorkspaceChanged
    signal valuesChanged

    Connections {
        target: root.name === "hyprland" ? Hyprland : null
        function onRawEvent(event) {
            root.rawEvent(event);
        }
        function onFocusedWorkspaceChanged() {
            root.focusedWorkspaceChanged();
        }
    }
    Connections {
        target: root.name === "hyprland" ? Hyprland.workspaces : null
        function onValuesChanged() {
            root.valuesChanged();
        }
    }

    function dispatchWorkspace(id) {
        if (Hyprland.usingLua) {
            if (root.debug)
                console.log("[WSBTN]", id, "no ws object, lua dispatch");
            Hyprland.dispatch('hl.dsp.focus({ workspace = "' + id + '" })');
        } else {
            if (root.debug)
                console.log("[WSBTN]", id, "no ws object, classic dispatch");
            Hyprland.dispatch("workspace " + id);
        }
    }
}
