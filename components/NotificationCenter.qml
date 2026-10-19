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
    readonly property bool popupSuppressed: center.fullscreenDnd && Style.fullscreenActive

    property bool panelOpen: false

    property string panelScreen: ""

    property bool hasUnread: false

    property var history: []

    property bool historyLoaded: false

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
            historySave.command = ["sh", "-c", Style.atomicWriteCmd(center.stateDir + "/notification-history.json", JSON.stringify(center.history))];
            historySave.running = true;
        }
    }

    Process {
        id: historySave
        running: false
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

                const out = [];
                for (const e of list) {
                    if (!e || e.id === undefined)
                        continue;
                    out.push(Object.assign({}, e, {
                        id: 1000000 + out.length,
                        open: false
                    }));
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

    function pushEntry(entry) {
        const list = center.history.slice();
        list.unshift(entry);
        if (list.length > center.historyLimit)
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
                    console.log("[NOTIFY] trim dismiss 异常:", e);
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
                        console.log("[ACTIVATE] actions 异常:", e);
                }
                break;
            }
        }
        if (!handled)
            handled = Style.focusAppWindow([entry.desktopEntry, entry.appIcon, entry.appName]);
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
                return;
            }
            if (Style.debug) {
                console.log("[NOTIFY] t=" + Date.now() + " 收到:", n.appName, "/", n.summary, "urgency=" + n.urgency, "timeout=" + n.expireTimeout);
            }
            center.onArrive(n);
            center.armTest(n);
        }
    }
}
