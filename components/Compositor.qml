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
                if (root.sameWid(old.wid, w.id)) {
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

        root.niriTitlePending = {};
        niriTitleFlush.stop();
        niriTitleDeadline.stop();
        root.niriWindows = kept;
    }

    property var niriTitlePending: ({})
    Timer {
        id: niriTitleFlush
        interval: 50
        repeat: false
        onTriggered: root.flushNiriTitles()
    }

    Timer {
        id: niriTitleDeadline
        interval: 200
        repeat: false
        onTriggered: root.flushNiriTitles()
    }
    function queueNiriTitle(wid, title) {
        const had = root.niriTitlePending && Object.keys(root.niriTitlePending).length > 0;
        const m = Object.assign({}, root.niriTitlePending);
        m[String(wid)] = String(title || "");
        root.niriTitlePending = m;
        if (!had)
            niriTitleDeadline.restart();
        niriTitleFlush.restart();
    }
    function flushNiriTitles() {
        niriTitleDeadline.stop();
        const m = root.niriTitlePending;
        if (!m || Object.keys(m).length === 0)
            return;
        root.niriTitlePending = {};
        for (const w of root.niriWindows) {
            const t = m[String(w.wid)];
            if (t !== undefined)
                w.obj.title = t;
        }
        root.niriWindows = root.niriWindows.slice();
        root.compositorUpdated();
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
            const act = root.niriWsList.find(ws => ws.id === v.id);
            if (v.focused === false && act) {
                for (const ws of root.niriWsList) {
                    if (ws.id === v.id)
                        ws.focused = true;
                    else if (ws.focused && ws.output === act.output)
                        ws.focused = false;
                }
                root.niriWsList = root.niriWsList.slice();
            } else if (v.focused !== false) {
                for (const ws of root.niriWsList)
                    ws.focused = ws.id === v.id;

                root.niriWsList = root.niriWsList.slice();
                for (const ws of root.niriWsList)
                    if (ws.focused) {
                        root.niriFocusedIdx = ws.idx;
                        root.niriFocusedOutput = ws.output;
                    }
            }
        } else if (key === "WindowsChanged") {
            root.applyNiriWindows(v.windows);
        } else if (key === "WindowOpenedOrChanged") {
            const w = v.window;
            const app = String(w.app_id || "");
            let found = null;
            for (const old of root.niriWindows)
                if (root.sameWid(old.wid, w.id)) {
                    found = old;
                    break;
                }
            if (found) {
                const title = String(w.title || "");
                const focused = !!w.is_focused;
                const urgent = !!w.is_urgent;

                if (found.obj.title !== title && found.obj.class === app && found.obj.wayland.appId === app && found.obj.lastIpcObject.class === app && found.obj.urgent === urgent && found.wsid === w.workspace_id && found.focused === focused) {
                    root.queueNiriTitle(w.id, title);
                    return;
                }
                found.obj.title = title;
                found.obj.class = app;
                found.obj.wayland.appId = app;
                found.obj.lastIpcObject.class = app;
                found.obj.urgent = urgent;
                found.wsid = w.workspace_id;
                found.focused = focused;

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
            root.niriWindows = root.niriWindows.filter(w => !root.sameWid(w.wid, cid));
        } else if (key === "WindowFocusChanged") {
            for (const w of root.niriWindows)
                w.focused = root.sameWid(w.wid, v.id);

            root.niriWindows = root.niriWindows.slice();
        } else if (key === "WindowTitleChanged") {
            root.queueNiriTitle(v.id, v.title);
            return;
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
        } else {}
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
            Hyprland.dispatch('hl.dsp.dpms({ action = "' + (enable ? "on" : "off") + '" })');
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

    readonly property int wsCapMax: 20

    function stripCount(outputName) {
        let n = 10;
        const cap = root.wsCapMax;
        const bump = function (idx) {
            if (idx > n && idx <= cap)
                n = idx;
        };
        if (root.name === "niri") {
            let m = 1;
            for (const ws of root.niriWsList) {
                if (outputName !== "" && ws.output !== outputName)
                    continue;
                if (ws.idx > m && ws.idx <= cap)
                    m = ws.idx;
            }
            if (root.niriFocusedOutput === outputName && root.niriFocusedIdx > m && root.niriFocusedIdx <= cap)
                m = root.niriFocusedIdx;
            return m;
        }
        for (const w of root.modelValues(Hyprland.workspaces)) {
            if (!w || w.id < 1 || w.id > cap)
                continue;
            const wmon = typeof w.monitor === "string" ? w.monitor : (w.monitor ? w.monitor.name : "");
            if (outputName !== "" && wmon !== "" && wmon !== outputName)
                continue;
            bump(w.id);
        }
        return n;
    }

    function prepareEmptyWorkspaceForLaunch() {
        let switched = false;
        if (root.name === "niri") {
            const out = root.niriFocusedOutput;
            if (out === "" || root.niriFocusedIdx < 0)
                return false;
            if (windowsForWorkspace(root.niriFocusedIdx, out).length === 0)
                return false;
            let firstEmpty = -1;
            for (const ws of root.niriWsList) {
                if (ws.output !== out)
                    continue;

                if (ws.idx >= 1 && ws.idx <= root.wsCapMax && ws.idx !== root.niriFocusedIdx && firstEmpty < 0 && windowsForWorkspace(ws.idx, out).length === 0)
                    firstEmpty = ws.idx;
            }

            if (firstEmpty >= 0) {
                activateWorkspace(firstEmpty, out);
                switched = true;
            }
            if (switched)
                root.kickEmptyWsResync();
            return switched;
        }

        let focusedId = -1;
        const occupied = {};
        const mon = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
        for (const w of root.modelValues(Hyprland.workspaces)) {
            if (!w || w.id < 1 || w.id > root.wsCapMax)
                continue;

            const wmon = typeof w.monitor === "string" ? w.monitor : (w.monitor ? w.monitor.name : "");
            if (mon !== "" && wmon !== "" && wmon !== mon) {
                occupied[w.id] = true;
                continue;
            }
            if (w.focused)
                focusedId = w.id;
            if (root.modelValues(w.toplevels).length > 0)
                occupied[w.id] = true;
        }
        if (focusedId < 0)
            return false;
        if (!occupied[focusedId])
            return false;
        let firstEmpty = -1;
        for (let id = 1; id <= root.wsCapMax; id++) {
            if (id === focusedId)
                continue;
            if (!occupied[id]) {
                firstEmpty = id;
                break;
            }
        }

        if (firstEmpty > 0) {
            activateWorkspace(firstEmpty);
            switched = true;
            root.kickEmptyWsResync();
        }
        return switched;
    }

    Timer {
        id: emptyWsResyncA
        interval: 1500
        onTriggered: root.requestToplevelResync("empty-ws-1")
    }
    Timer {
        id: emptyWsResyncB
        interval: 4500
        onTriggered: root.requestToplevelResync("empty-ws-2")
    }
    function kickEmptyWsResync() {
        emptyWsResyncA.restart();
        emptyWsResyncB.restart();
    }

    property string pendingMoveTarget: ""
    property real wsCursorX: 0
    property real wsCursorY: 16

    function sameWid(a, b) {
        return String(a) === String(b);
    }

    function moveWindowToWorkspace(address, targetWs, dropX, dropY, outputName) {
        if (root.name === "niri") {
            if (outputName === undefined || outputName === "" || outputName === root.niriFocusedOutput) {
                Quickshell.execDetached(["niri", "msg", "action", "move-window-to-workspace", "--window-id", String(address), String(targetWs)]);
            } else {
                Quickshell.execDetached(["sh", "-c", "niri msg action focus-monitor " + root.sq(outputName) + " && niri msg action move-window-to-workspace --window-id " + root.sq(String(address)) + " " + root.sq(String(targetWs))]);
            }
            return;
        }

        const a = String(address);
        const full = a.startsWith("0x") ? a : "0x" + a;
        if (!Hyprland.usingLua) {
            Hyprland.dispatch("movetoworkspace " + String(targetWs) + ",address:" + full);
            return;
        }
        Hyprland.dispatch('hl.dsp.focus({ window = "address:' + root.luaStr(full) + '" })');
        wsCursorX = dropX;
        wsCursorY = dropY;
        pendingMoveTarget = String(targetWs);
        settleMoveTimer.restart();
    }
    Timer {
        id: settleMoveTimer
        interval: 80
        onTriggered: {
            Hyprland.dispatch('hl.dsp.window.move({ workspace = "' + root.luaStr(pendingMoveTarget) + '" })');

            Hyprland.dispatch('hl.dsp.cursor.move({ x = ' + Math.round(root.wsCursorX) + ', y = ' + Math.round(root.wsCursorY) + ' })');
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

    function toplevelIpcFingerprint(t) {
        try {
            const ipc = t ? t.lastIpcObject : null;
            if (ipc === undefined || ipc === null)
                return "<missing>";
            const text = JSON.stringify(ipc);
            return typeof text === "string" ? text : "<unserializable>";
        } catch (e) {
            return "<missing>";
        }
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
        fhPickup.sentinelSnap = root.toplevelIpcFingerprint(best);
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

    property bool notificationPulsePending: false
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
        if (root.notificationPulseRefreshing) {
            root.notificationPulsePending = true;
            return;
        }
        root.startNotificationPulseRefresh();
    }

    function startNotificationPulseRefresh() {
        root.notificationPulseRefreshing = true;
        root.notificationPulsePending = false;
        root.notificationPulseSentinels = [];
        for (const ws of root.modelValues(Hyprland.workspaces)) {
            for (const t of root.modelValues(ws.toplevels)) {
                if (t)
                    root.notificationPulseSentinels.push({
                        toplevel: t,
                        snap: root.toplevelIpcFingerprint(t)
                    });
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

        const target = root.notificationPulseTarget(keys);
        root.notificationPulseKeys = [];
        root.notificationPulseRefreshing = false;
        root.notificationPulsePending = false;
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

            let refreshed = false;
            for (const pair of root.notificationPulseSentinels) {
                if (root.toplevelIpcFingerprint(pair.toplevel) !== pair.snap) {
                    refreshed = true;
                    break;
                }
            }
            if (!refreshed && pulseRefreshTimer.attempts < 10)
                return;
            if (root.notificationPulsePending) {
                root.startNotificationPulseRefresh();
                return;
            }
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
        property string sentinelSnap: ""
        property int attempts: 0
        onTriggered: {
            fhPickup.attempts++;
            const refreshed = !fhPickup.sentinelToplevel || root.toplevelIpcFingerprint(fhPickup.sentinelToplevel) !== fhPickup.sentinelSnap;
            if (!refreshed && fhPickup.attempts < 20)
                return;
            fhPickup.stop();
            root.finishFocusPickup(refreshed);
        }
    }

    function finishFocusPickup(refreshed) {
        let cls = "";
        let addr = "";
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
        if (addr === "" && cls === "") {
            cls = fhPickup.fallbackCls;
            addr = fhPickup.fallbackAddr;
        }
        if (root.debug) {
            console.log("[FOCUS] pickup " + (refreshed ? "refreshed" : "timeout") + " after " + (fhPickup.attempts * fhPickup.interval) + "ms");
        }
        fhPickup.sentinelToplevel = null;
        fhPickup.sentinelSnap = "";
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

        if (Array.isArray(model))
            return model;
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
        let fallback = null;
        const name = String(id);
        for (const w of root.modelValues(Hyprland.workspaces)) {
            if (!w)
                continue;
            if (w.id === id)
                return w;
            if (fallback === null && w.name === name)
                fallback = w;
        }
        return fallback;
    }

    function workspacesDump() {
        return root.modelValues(Hyprland.workspaces).map(w => (w && w.id !== undefined ? w.id : "?") + ":" + (w ? w.name : "?")).join(",");
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

            Hyprland.dispatch('hl.dsp.focus({ workspace = "' + root.luaStr(String(id)) + '" })');
        } else {
            if (root.debug)
                console.log("[WSBTN]", id, "no ws object, classic dispatch");
            Hyprland.dispatch("workspace " + id);
        }
    }

    property bool toplevelResyncInFlight: false
    property var toplevelResyncSentinels: []
    property int toplevelResyncCountBefore: 0
    property int toplevelResyncAttempts: 0
    property string toplevelResyncReason: ""
    property string toplevelResyncActiveReason: ""

    property bool toplevelResyncPending: false

    function toplevelSnapshot() {
        const sentinels = [];
        let count = 0;
        for (const ws of root.modelValues(Hyprland.workspaces)) {
            for (const t of root.modelValues(ws.toplevels)) {
                count++;
                if (t)
                    sentinels.push({
                        toplevel: t,
                        snap: root.toplevelIpcFingerprint(t)
                    });
            }
        }
        return {
            count: count,
            sentinels: sentinels
        };
    }

    function requestToplevelResync(reason) {
        if (root.name !== "hyprland")
            return;
        root.toplevelResyncReason = String(reason || "");
        if (root.toplevelResyncInFlight) {
            root.toplevelResyncPending = true;
            return;
        }
        toplevelResyncDebounce.restart();
    }

    function toplevelResyncSnapshotChanged() {
        let count = 0;
        for (const ws of root.modelValues(Hyprland.workspaces))
            count += root.modelValues(ws.toplevels).length;

        if (root.toplevelResyncSentinels.length === 0)
            return count > 0 && root.toplevelResyncCountBefore === 0;

        for (const pair of root.toplevelResyncSentinels)
            if (root.toplevelIpcFingerprint(pair.toplevel) !== pair.snap)
                return true;
        return false;
    }

    function finishToplevelResync(refreshed) {
        const rerun = root.toplevelResyncPending;
        toplevelResyncPoll.stop();
        root.toplevelResyncInFlight = false;
        root.toplevelResyncPending = false;
        root.toplevelResyncSentinels = [];
        root.toplevelResyncCountBefore = 0;
        root.toplevelResyncAttempts = 0;
        if (root.debug) {
            console.log("[QS] toplevel resync " + root.toplevelResyncActiveReason + (refreshed ? " ready" : " timeout"));
        }

        root.rawEvent({
            name: "openwindow",
            data: ""
        });
        if (rerun && root.name === "hyprland")
            toplevelResyncDebounce.restart();
    }

    function beginToplevelResync() {
        if (root.name !== "hyprland" || root.toplevelResyncInFlight)
            return;
        root.toplevelResyncPending = false;

        root.toplevelResyncActiveReason = root.toplevelResyncReason;
        const snapshot = root.toplevelSnapshot();
        root.toplevelResyncSentinels = snapshot.sentinels;
        root.toplevelResyncCountBefore = snapshot.count;
        root.toplevelResyncAttempts = 0;
        root.toplevelResyncInFlight = true;
        let requested = true;
        try {
            Hyprland.refreshToplevels();
        } catch (e) {
            requested = false;
            console.warn("[QS] refreshToplevels failed: " + e);
        }
        if (requested)
            toplevelResyncPoll.restart();
        else
            root.finishToplevelResync(false);
    }

    Timer {
        id: toplevelResyncDebounce
        interval: 100
        repeat: false
        onTriggered: root.beginToplevelResync()
    }
    Timer {
        id: toplevelResyncPoll
        interval: 50
        repeat: true
        onTriggered: {
            root.toplevelResyncAttempts++;
            const refreshed = root.toplevelResyncSnapshotChanged();
            if (refreshed || root.toplevelResyncAttempts >= 20)
                root.finishToplevelResync(refreshed);
        }
    }

    Timer {
        id: loginResync1
        interval: 4000
        repeat: false
        running: root.name === "hyprland"
        onTriggered: {
            if (root.debug)
                console.log("[QS] login resync 1 (openwindow drop self-heal)");
            root.requestToplevelResync("login-4s");
        }
    }
    Timer {
        id: loginResync2
        interval: 12000
        repeat: false
        running: root.name === "hyprland"
        onTriggered: {
            if (root.debug)
                console.log("[QS] login resync 2 (openwindow drop self-heal)");
            root.requestToplevelResync("login-12s");
        }
    }
}
