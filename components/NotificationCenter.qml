import QtQuick
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
    property bool historyLoadCorrupt: false

    property int historyLoadGen: 0

    property bool historySettled: false

    property var pendingReplay: []

    readonly property string stateDir: Style.stateDir

    readonly property var server: notifServer
    readonly property int openCount: Style.modelValues(notifServer.trackedNotifications).length

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

    onHistoryChanged: if (center.historyLoaded)
        center.saveHistory()

    function saveHistory() {
        if (center.historyLoadCorrupt)
            return;
        historyJsonStore.requestSave();
    }

    JsonStore {
        id: historyJsonStore
        path: center.stateDir + "/notification-history.json"
        defaultText: "[]"
        debounceMode: "tick"
        retryLimit: 3
        retryIntervalMs: 1000
        serialize: () => JSON.stringify(center.historyForSave())
        onTextLoaded: text => {
            const gen = center.historyLoadGen;
            let list = [];
            let parseOk = true;

            if (String(text).length > 5 * 1024 * 1024)
                parseOk = false;
            try {
                if (parseOk)
                    list = JSON.parse(text);
            } catch (e) {
                parseOk = false;
            }
            if (!parseOk) {
                center.historyLoadCorrupt = true;
                console.warn("[NOTIFY] history JSON is corrupt; quarantining as .corrupt");
                historyQuarantine.running = true;
            }
            if (!parseOk)
                list = [];

            if (!Array.isArray(list))
                list = [];

            list = list.slice(0, 500);

            if (center.historyLoadGen !== gen) {
                center.historyLoaded = true;

                center.pendingReplay = [];
                return;
            }

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

            for (const rn of center.pendingReplay)
                center.replayWriteback(rn);
            center.pendingReplay = [];
        }
        onSaveFailed: (code, failures) => console.warn("[NOTIFY] history save failed, exitCode " + code + " (attempt " + failures + ")")
    }

    Process {
        id: historyQuarantine
        running: false
        command: ["sh", "-c", "mv -f " + Style.sq(center.stateDir + "/notification-history.json") + " " + Style.sq(center.stateDir + "/notification-history.json.corrupt")]
        onExited: code => {
            if (code !== 0) {
                console.warn("[NOTIFY] could not quarantine corrupt history, exit " + code);

                historyQuarantineFailedNotify.restart();
                return;
            }
            center.historyLoadCorrupt = false;

            historyCorruptNotify.restart();
            if (center.historyLoaded)
                center.saveHistory();
        }
    }
    Timer {
        id: historyCorruptNotify
        interval: 1500
        repeat: false
        onTriggered: Style.notifySimple(I18n.t("notif.historyCorrupt"), I18n.t("notif.historyCorruptBody"))
    }
    Timer {
        id: historyQuarantineFailedNotify
        interval: 1500
        repeat: false
        onTriggered: Style.notifySimple(I18n.t("notif.historyCorrupt"), I18n.t("notif.historyCorruptStuck"))
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

            const c = {
                id: e.id,
                time: e.time,
                urgency: e.urgency,
                open: !!e.open,
                detail: !!e.detail,
                burst: (typeof e.burst === "number" && isFinite(e.burst) && e.burst > 1) ? Math.floor(e.burst) : 1
            };
            c.appName = center.historyText(e.appName, 256);
            c.summary = center.historyText(e.summary, 1024);
            c.body = center.historyText(e.body, 4096);
            c.appIcon = center.historyText(e.appIcon, 512);
            c.image = center.historyText(e.image, 512);
            c.desktopEntry = center.historyText(e.desktopEntry, 256);
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

    function replayWriteback(n) {
        const h = center.history;
        for (let i = 0; i < h.length; i++) {
            const e = h[i];
            if (!e)
                continue;
            if (String(e.appName || "") === String(n.appName || "") && String(e.summary || "") === String(n.summary || "") && String(e.body || "") === String(n.body || "")) {
                const copy = h.slice();

                copy[i] = Object.assign({}, copy[i], {
                    open: true,
                    liveId: n.id
                });
                center.history = copy;
                return;
            }
        }
        center.pushEntry(center.snapshot(n, true));
    }

    function applyHistoryLimit() {
        if (center.history.length > center.historyLimit)
            center.history = center.history.slice(0, center.historyLimit);
    }

    function clearAll() {
        center.history = [];
        center.hasUnread = false;
        center.dismissAllOpen();
        center.historyLoadGen++;
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
            if ((list[i].id === id || list[i].liveId === id) && list[i].open) {
                const upd = Object.assign({}, list[i], {
                    open: false
                });
                delete upd.liveId;
                list[i] = upd;
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

    NotificationServer {
        id: notifServer

        bodySupported: true
        imageSupported: true
        actionsSupported: true

        onNotification: n => {
            if (n.lastGeneration) {
                n.tracked = true;

                if (!center.historyLoaded) {
                    center.pendingReplay = center.pendingReplay.concat([n]);

                    Qt.callLater(center.trimTracked);
                    return;
                }
                center.replayWriteback(n);

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
