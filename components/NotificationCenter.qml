import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Item {
    id: center

    property int maxVisible: 5

    property int maxTracked: 50

    property int historyLimit: 20

    property bool dnd: false

    property bool fullscreenDnd: true
    readonly property bool popupSuppressed: center.fullscreenDnd && Compositor.fullscreenActive

    readonly property bool criticalTracked: {
        const list = Style.modelValues(notifServer.trackedNotifications);
        for (let i = 0; i < list.length; i++)
            if (list[i] && list[i].urgency === 2)
                return true;
        return false;
    }

    property bool panelOpen: false

    property string panelScreen: ""

    property bool hasUnread: false

    property int burstWindowMs: 120000

    property bool lastChangeWasBurst: false

    property var history: []

    property bool historyLoaded: false

    property bool historySettled: false

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Style.home + "/.local/state")) + "/quickshell"

    readonly property var server: notifServer
    readonly property int openCount: Style.modelValues(notifServer.trackedNotifications).length

    onHistoryChanged: if (center.historyLoaded)
        center.saveHistory()

    function saveHistory() {
        historySaveDebounce.restart();
    }

    Timer {
        id: historySaveDebounce
        interval: 200
        onTriggered: {
            if (historySave.running) {
                restart();
                return;
            }
            historySave.command = ["sh", "-c", Style.atomicWriteCmd(center.stateDir + "/notification-history.json", JSON.stringify(center.historyForSave()))];
            historySave.running = true;
        }
    }

    Process {
        id: historySave
        running: false
        onExited: exitCode => {
            if (exitCode !== 0)
                console.warn("[NOTIFY] history save failed, exitCode " + exitCode);
        }
    }

    Process {
        id: historyLoad
        running: true
        command: ["sh", "-c", Style.readJsonCmd(center.stateDir + "/notification-history.json", "[]")]
        stdout: StdioCollector {
            onStreamFinished: {
                let list = [];
                try {
                    list = JSON.parse(text);
                } catch (e) {
                    list = [];
                }

                if (!Array.isArray(list))
                    list = [];

                const out = [];
                for (const e of list) {
                    if (!e || e.id === undefined)
                        continue;
                    const copy = Object.assign({}, e, {
                        id: 1000000 + out.length,
                        open: false
                    });
                    if (Array.isArray(copy.members)) {
                        copy.members = copy.members.map(function (m, k) {
                            return (m && typeof m === "object") ? Object.assign({}, m, {
                                id: 2000000 + out.length * 100 + k
                            }) : m;
                        });
                    }
                    out.push(copy);
                }

                center.history = center.history.concat(out);
                center.historyLoaded = true;
            }
        }
    }

    function toggleDnd() {
        center.dnd = !center.dnd;
    }

    function togglePanel(screenName) {
        if (center.panelOpen && center.panelScreen === screenName) {
            center.panelOpen = false;
        } else {
            center.panelScreen = screenName;
            center.panelOpen = true;
            center.hasUnread = false;
        }
    }

    function closePanel() {
        center.panelOpen = false;
    }

    Timer {
        interval: 3000
        repeat: true
        running: center.panelOpen && center.openCount === 0 && center.history.length === 0
        onTriggered: center.closePanel()
    }

    function dismissAllOpen() {
        for (const n of Style.modelValues(notifServer.trackedNotifications)) {
            if (n)
                n.dismiss();
        }
    }

    function snapshot(n, isOpen) {
        return {
            id: n.id,
            appName: n.appName,
            summary: n.summary,
            body: n.body,
            urgency: n.urgency,
            appIcon: n.appIcon,
            image: n.image,
            desktopEntry: n.desktopEntry,
            time: Date.now(),
            open: isOpen,
            detail: !!(n.hints && String(n.hints["x-quickshell-reboot"] || "") !== "")
        };
    }

    function historyText(v, max) {
        const s = (v === undefined || v === null) ? "" : String(v);
        return s.length > max ? s.substring(0, max) + "…" : s;
    }

    function utf8ByteLen(s) {
        let n = 0;
        for (let i = 0; i < s.length; i++) {
            const c = s.charCodeAt(i);
            if (c < 0x80)
                n += 1;
            else if (c < 0x800)
                n += 2;
            else if (c >= 0xD800 && c < 0xDC00) {
                n += 4;
                i++;
            } else
                n += 3;
        }
        return n;
    }

    function historyForSave() {
        const out = [];
        for (const e of center.history) {
            if (!e)
                continue;
            const c = Object.assign({}, e);
            c.appName = center.historyText(c.appName, 256);
            c.summary = center.historyText(c.summary, 1024);
            c.body = center.historyText(c.body, 4096);
            c.appIcon = center.historyText(c.appIcon, 512);
            c.image = center.historyText(c.image, 512);
            c.desktopEntry = center.historyText(c.desktopEntry, 256);
            if (e.members) {
                const ms = [];
                for (let i = 0; i < e.members.length && i < 20; i++) {
                    const m = e.members[i];
                    if (!m || typeof m !== "object")
                        continue;
                    ms.push({
                        id: m.id,
                        time: m.time,
                        body: center.historyText(m.body, 1024)
                    });
                }
                c.members = ms;
            }
            out.push(c);
        }

        const ARG_BUDGET = 120000;
        let used = 2;
        let keep = 0;
        for (let i = 0; i < out.length; i++) {
            const j = JSON.stringify(out[i]);
            const need = center.utf8ByteLen(j) + 3 * (j.split("'").length - 1) + (keep > 0 ? 1 : 0);
            if (used + need > ARG_BUDGET)
                break;
            used += need;
            keep = i + 1;
        }
        if (keep === 0 && out.length > 0) {
            const c0 = Object.assign({}, out[0]);
            delete c0.members;
            for (; ; ) {
                const j0 = JSON.stringify(c0);
                if (center.utf8ByteLen(j0) + 3 * (j0.split("'").length - 1) + 2 <= ARG_BUDGET)
                    break;
                if (c0.body === undefined || c0.body.length <= 64)
                    break;
                c0.body = c0.body.substring(0, Math.floor(c0.body.length / 2));
            }
            out.length = 0;
            out.push(c0);
        } else {
            out.length = keep;
        }
        return out;
    }

    function pushEntry(entry) {
        const list = center.history.slice();
        const head = list[0];
        if (head && entry.appName !== undefined && entry.summary !== undefined && entry.appName !== "" && entry.summary !== "" && entry.urgency !== 2 && head.urgency !== 2 && head.appName === entry.appName && head.summary === entry.summary && entry.time - head.time <= center.burstWindowMs) {
            entry.burst = (head.burst || 1) + 1;

            const prior = [];
            if (head.members) {
                for (let i = 0; i < head.members.length; i++) {
                    const m = head.members[i];

                    if (m && typeof m === "object" && typeof m.body === "string")
                        prior.push({
                            id: m.id,
                            time: m.time,
                            body: m.body
                        });
                }
            }
            if (prior.length === 0 && head.body !== "")
                prior.push({
                    id: head.id,
                    time: head.time,
                    body: head.body
                });
            prior.push({
                id: entry.id,
                time: entry.time,
                body: entry.body
            });
            while (prior.length > 20)
                prior.shift();
            entry.members = prior;
            list[0] = entry;
            center.lastChangeWasBurst = true;
        } else {
            list.unshift(entry);
            center.lastChangeWasBurst = false;
        }

        if (center.historySettled && list.length > center.historyLimit)
            list.length = center.historyLimit;
        center.history = list;
    }

    function applyHistoryLimit() {
        if (center.history.length > center.historyLimit)
            center.history = center.history.slice(0, center.historyLimit);
    }

    function onArrive(n) {
        center.hasUnread = true;
        center.pushEntry(center.snapshot(n, !center.dnd));

        if (center.dnd)
            return;
        n.tracked = true;

        Qt.callLater(center.trimTracked);
    }

    function trimTracked() {
        const list = Style.modelValues(notifServer.trackedNotifications);
        const drop = list.length - center.maxTracked;
        for (let i = 0; i < drop; i++) {
            const n = list[i];
            if (!n)
                continue;
            try {
                n.dismiss();
            } catch (e) {
                if (Style.debug)
                    console.log("[NOTIFY] trim dismiss exception:", e);
            }
        }
    }

    function markClosed(id) {
        const list = center.history.slice();
        for (let i = 0; i < list.length; i++) {
            if (list[i].id === id && list[i].open) {
                list[i] = Object.assign({}, list[i], {
                    open: false
                });
                center.history = list;
                return;
            }
        }
    }

    function removeEntry(id) {
        const list = [];
        for (const e of center.history) {
            if (e.id === id) {
                if (e.open)
                    center.dismissOne(id);
                if (e.members) {
                    for (let i = 0; i < e.members.length; i++) {
                        const m = e.members[i];
                        if (m && m.id !== undefined && m.id !== id)
                            center.dismissOne(m.id);
                    }
                }
            } else {
                list.push(e);
            }
        }
        center.history = list;
    }

    function dismissOne(id) {
        for (const n of Style.modelValues(notifServer.trackedNotifications)) {
            if (n && n.id === id)
                n.dismiss();
        }
    }

    function activateEntry(entry) {
        if (Style.debug)
            console.log("[ACTIVATE] entry:", JSON.stringify(entry));
        if (!entry)
            return;
        let handled = false;

        if (entry.open) {
            for (const n of Style.modelValues(notifServer.trackedNotifications)) {
                if (!n || n.id !== entry.id)
                    continue;
                try {
                    for (const a of Style.modelValues(n.actions)) {
                        if (Style.debug)
                            console.log("[ACTIVATE] action id=", a.identifier, "label=", a.text);
                        if (a.identifier === "default") {
                            a.invoke();
                            handled = true;
                            break;
                        }
                    }
                } catch (e) {
                    if (Style.debug)
                        console.log("[ACTIVATE] actions exception:", e);
                }
                break;
            }
        }
        if (!handled)
            handled = Compositor.focusAppWindow([entry.desktopEntry, entry.appIcon, entry.appName]);
        if (!handled && entry.desktopEntry && entry.desktopEntry !== "") {
            Style.launchDesktop(entry.desktopEntry);
            handled = true;
        }

        if (handled)
            center.closePanel();
    }

    property var testEntry: null
    function armTest(n) {
        if (!Style.debug)
            return;
        center.testEntry = center.snapshot(n, !center.dnd);
        testTimer.restart();
    }
    Timer {
        id: testTimer
        interval: 1500
        onTriggered: if (center.testEntry)
            center.activateEntry(center.testEntry)
    }

    function clearAll() {
        center.history = [];
        center.hasUnread = false;
        center.dismissAllOpen();
    }

    NotificationServer {
        id: notifServer

        bodySupported: true
        imageSupported: true
        actionsSupported: true

        onNotification: n => {
            if (n.lastGeneration) {
                n.tracked = true;

                Qt.callLater(center.trimTracked);
                return;
            }
            if (Style.debug) {
                console.log("[NOTIFY] t=" + Date.now() + " received:", n.appName, "/", n.summary, "urgency=" + n.urgency, "timeout=" + n.expireTimeout);
            }
            center.onArrive(n);

            if (!center.dnd && !center.popupSuppressed)
                Compositor.requestNotificationPulse([n.appName, n.desktopEntry, n.appIcon]);
            center.armTest(n);
        }
    }
}
