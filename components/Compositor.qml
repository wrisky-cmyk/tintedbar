pragma Singleton

import QtQuick
import QtQml
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Item {
    id: root

    readonly property bool debug: Quickshell.env("QS_DEBUG") === "1"

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
        command: ["sh", "-c", "for i in $(seq 1 50); do [ -S \"$NIRI_SOCKET\" ] && break; sleep 0.2; done; " + "niri msg --json windows; printf '\n--WS--\n'; niri msg --json workspaces"]
        stdout: StdioCollector {
            onStreamFinished: {
                let sawMarker = false;
                const stage = {
                    s: "windows"
                };
                for (const line of String(text).split("\n")) {
                    const t = line.trim();
                    if (t === "")
                        continue;
                    if (t === "--WS--") {
                        stage.s = "workspaces";
                        sawMarker = true;
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
                root.niriRebind();
                root.compositorUpdated();
                if (!sawMarker && root.name === "niri" && niriSnapshotRetry.retryCount < 3)
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
                    wsIdx: 1,
                    layout: w.layout,
                    obj: {
                        __wid: w.id,
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
                e.wsid = w.workspace_id;
                e.layout = w.layout;
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

    function niriRebind() {
        const idxById = {};
        for (const ws of root.niriWsList)
            idxById[ws.id] = ws.idx;
        for (const w of root.niriWindows)
            w.wsIdx = idxById[w.wsid] || 1;
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
            root.niriRebind();
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
            root.niriRebind();
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
                found.wsid = w.workspace_id;
                found.focused = !!w.is_focused;
                found.layout = w.layout;

                root.niriWindows = root.niriWindows.slice();
            } else {
                root.niriWindows = root.niriWindows.concat([
                    {
                        wid: w.id,
                        wsid: w.workspace_id,
                        focused: !!w.is_focused,
                        wsIdx: 1,
                        layout: w.layout,
                        obj: {
                            __wid: w.id,
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
            root.niriRebind();
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
        } else if (key === "KeyboardLayoutsChanged") {
            const kb = v.keyboard_layouts || {};
            root.niriLayoutNames = kb.names || [];
            root.niriLayout = String(root.niriLayoutNames[kb.current_idx] || "");
        } else if (key === "KeyboardLayoutSwitched") {
            root.niriLayout = String(root.niriLayoutNames[v.idx] || v.idx);
        } else if (key === "WindowLayoutsChanged") {
            for (const c of (v.changes || [])) {
                const wid = Array.isArray(c) ? c[0] : c.id;
                const layout = Array.isArray(c) ? c[1] : c.layout;
                for (const w of root.niriWindows)
                    if (String(w.wid) === String(wid)) {
                        w.layout = layout;
                        break;
                    }
            }
        } else if (key === "ConfigLoaded") {
            return;
        } else {
            return;
        }
        root.recomputeNiriFullscreen();
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
            Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.dpms(\"" + (enable ? "on" : "off") + "\")"]);
        } else {
            Quickshell.execDetached(["hyprctl", "dispatch", "dpms", enable ? "on" : "off"]);
        }
    }

    function closeWindow() {
        if (root.name === "niri") {
            Quickshell.execDetached(["niri", "msg", "action", "close-window"]);
            return;
        }
        if (Hyprland.usingLua) {
            Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.window.close()"]);
        } else {
            Quickshell.execDetached(["hyprctl", "dispatch", "killwindow"]);
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

    property bool fullscreenActive: false

    onFullscreenActiveChanged: console.log("[FS] focused window fullscreen = " + (fullscreenActive ? "yes" : "no"))

    property bool fullscreenWatch: true
    Process {
        id: hyprFullscreenQuery
        running: false

        command: ["sh", "-c", "hyprctl -j activewindow 2>/dev/null | tr ',' '\\n' " + "| grep -oE '\"fullscreen[^\"]*\": *[0-9]+' | grep -oE '[0-9]+$' | sort -n | tail -1"]
        stdout: StdioCollector {

            onStreamFinished: root.fullscreenActive = Number(String(text).trim() || "0") >= 2
        }
    }

    function refreshHyprFullscreen() {
        hyprFullscreenQuery.running = true;
    }

    Timer {
        interval: 60000
        repeat: true
        running: root.name === "hyprland" && root.fullscreenWatch
        triggeredOnStart: true
        onTriggered: root.refreshHyprFullscreen()
    }
    Connections {
        target: root.name === "hyprland" ? Hyprland : null
        function onRawEvent(event) {
            const n = String(event.name);
            if (n !== "fullscreen" && n !== "fullscreenv2")
                return;

            root.refreshHyprFullscreen();
        }
    }

    function recomputeNiriFullscreen() {
        if (root.name !== "niri")
            return;
        let w = null;
        for (const e of root.niriWindows)
            if (e.focused) {
                w = e;
                break;
            }
        const out = Quickshell.screens.find(s => s.name === root.niriFocusedOutput);
        root.fullscreenActive = !!(out && w && w.layout && w.layout.window_size && Number(w.layout.window_size[0]) === out.width && Number(w.layout.window_size[1]) === out.height);
    }

    Timer {
        interval: 30000
        repeat: true

        running: root.name === "niri" && root.fullscreenWatch
        triggeredOnStart: true
        onTriggered: niriFullscreenQuery.running = true
    }
    Process {
        id: niriFullscreenQuery
        command: ["niri", "msg", "--json", "focused-window"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const w = JSON.parse(text);
                    for (const e of root.niriWindows)
                        if (String(e.wid) === String(w.id)) {
                            e.layout = w.layout;
                            break;
                        }
                } catch (e) {}
                root.recomputeNiriFullscreen();
            }
        }
    }

    readonly property var appNameAlias: {
        "微信": "wechat",
        "企业微信": "wxwork",
        "QQ音乐": "qqmusic",
        "网易云音乐": "netease-cloud-music-gtk4"
    }

    function focusAppWindow(candidates) {
        const keys = [];
        for (const c of candidates) {
            if (!c)
                continue;
            const s = String(c).toLowerCase();
            if (s !== "" && keys.indexOf(s) < 0)
                keys.push(s);
            const alias = root.appNameAlias[String(c)];
            if (alias && keys.indexOf(alias) < 0)
                keys.push(alias);
        }
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

        if (focusPick.running) {
            focusPick.pendingKeys = keys;
            focusPick.pendingCls = bestCls;
            focusPick.pendingAddr = bestAddr;
            return true;
        }
        focusPick.candKeys = keys;
        focusPick.fallbackCls = bestCls;
        focusPick.fallbackAddr = bestAddr;
        focusPick.command = ["hyprctl", "-j", "clients"];
        focusPick.running = true;
        return true;
    }

    function matchKeys(cls, keys) {
        const c = String(cls || "").toLowerCase();
        if (c === "")
            return false;
        for (const k of keys)
            if (c.indexOf(k) >= 0 || k.indexOf(c) >= 0)
                return true;
        return false;
    }

    Process {
        id: focusPick
        property var candKeys: []
        property string fallbackCls: ""
        property string fallbackAddr: ""

        property var pendingKeys: []
        property string pendingCls: ""
        property string pendingAddr: ""

        onExited: if (pendingKeys.length > 0) {
            candKeys = pendingKeys;
            fallbackCls = pendingCls;
            fallbackAddr = pendingAddr;
            pendingKeys = [];
            pendingCls = "";
            pendingAddr = "";
            command = ["hyprctl", "-j", "clients"];
            running = true;
        }
        stdout: StdioCollector {
            onStreamFinished: {
                let list = [];
                try {
                    list = JSON.parse(text);
                } catch (e) {
                    list = [];
                }
                let cls = "";
                let addr = "";
                let fh = 1e9;
                for (const c of list) {
                    if (!root.matchKeys(String(c.class || ""), focusPick.candKeys))
                        continue;
                    const v = c.focusHistoryID;
                    const h = (typeof v === "number" && v >= 0) ? v : 1e9;
                    if (addr === "" || h < fh) {
                        cls = String(c.class || "");
                        addr = String(c.address || "");
                        fh = h;
                    }
                }

                if (addr === "" && cls === "") {
                    cls = focusPick.fallbackCls;
                    addr = focusPick.fallbackAddr;
                }
                if (addr === "" && cls === "")
                    return;
                root.focusWindowByAddress(cls, addr);
            }
        }
    }

    function focusWindowByAddress(cls, addr) {
        const sel = addr !== "" ? "address:" + root.luaStr(addr) : "class:" + root.luaStr(cls);

        if (Hyprland.usingLua) {
            Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ window = \"" + sel + "\" })"]);
        } else {
            Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", sel]);
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
