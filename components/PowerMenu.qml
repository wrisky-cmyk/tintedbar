import QtQuick
import Quickshell
import Quickshell.Io
import QtQuick.Effects
import "."

OverlayPanel {
    id: powerMenu

    readonly property string iconDir: Style.configDir + "/icons"

    function open() {
        visible = true;

        card.forceActiveFocus();

        if (!inhibitProbe.running)
            inhibitProbe.running = true;

        if (!uidProc.running)
            uidProc.running = true;
    }
    function close() {
        visible = false;
    }

    property var blockInhibitors: []
    readonly property bool hasBlockers: blockInhibitors.length > 0

    readonly property string blockerNames: blockInhibitors.map(b => b.who).join(I18n.effectiveLang === "zh" ? "、" : ", ")

    property bool notifyAfterProbe: false

    property string pendingOp: "poweroff"

    property int myUid: -1

    Component.onCompleted: if (!uidProc.running)
        uidProc.running = true

    Process {
        id: uidProc
        command: ["sh", "-c", "id -u"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const n = parseInt(String(text).trim());
                powerMenu.myUid = Number.isNaN(n) ? -1 : n;
            }
        }
    }

    Process {
        id: inhibitProbe
        command: ["busctl", "call", "--json=short", "org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager", "ListInhibitors"]
        stdout: StdioCollector {
            onStreamFinished: {
                let list = null;
                try {
                    list = [];

                    for (const it of JSON.parse(text).data[0])
                        if (it.length >= 4 && it[3] === "block" && String(it[0]).split(":").indexOf("shutdown") >= 0)
                            list.push({
                                what: String(it[0]),
                                who: String(it[1]),
                                mode: String(it[3]),
                                uid: it.length > 4 ? Number(it[4]) : -1,
                                pid: it.length > 5 ? Number(it[5]) : -1
                            });
                } catch (e) {
                    list = null;
                }
                if (list !== null) {
                    powerMenu.blockInhibitors = list;
                    powerMenu.blockersFreshAt = Date.now();
                }

                if (list !== null) {
                    if (powerMenu.pendingForceOp !== "")
                        powerMenu.resolveForce(true);
                    else if (powerMenu.graceful)
                        powerMenu.gracefulEvaluate();
                    else if (powerMenu.notifyAfterProbe) {
                        powerMenu.notifyAfterProbe = false;
                        powerMenu.notifyBlocked();
                    }
                }
            }
        }

        onExited: code => {
            if (powerMenu.pendingForceOp !== "" && code !== 0) {
                powerMenu.resolveForce(false);
            } else if (powerMenu.graceful && code !== 0) {
                powerMenu.gracefulEvaluate();
            } else if (powerMenu.notifyAfterProbe && code !== 0) {
                powerMenu.notifyAfterProbe = false;
                powerMenu.notifyBlocked();
            }
        }
    }

    function notifyBlocked() {
        notifyWatchdog.stop();
        const names = powerMenu.blockerNames;
        const op = powerMenu.pendingOp === "reboot" ? "reboot" : "poweroff";
        const actionId = op + "-force";
        const actionLabel = I18n.t(op === "reboot" ? "power.forceReboot" : "power.forcePoweroff");
        if (blockedNotifyProc.running)
            return;

        const title = names !== "" ? I18n.t("power.inhibit") : I18n.t("power.failed");
        const body = names !== "" ? I18n.t("power.inhibitBody") + names : I18n.t("power.failedBody");
        blockedNotifyProc.command = ["gdbus", "call", "--session", "--dest", "org.freedesktop.Notifications", "--object-path", "/org/freedesktop/Notifications", "--method", "org.freedesktop.Notifications.Notify", "quickshell", "0", "", title, body, "[" + Style.gvStr(actionId) + ", " + Style.gvStr(actionLabel) + "]", "{\"urgency\": <byte 2>, \"x-quickshell-power\": <\"" + op + "\">}", 20000];
        blockedNotifyProc.running = true;
    }

    Process {
        id: blockedNotifyProc
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "")
                    console.log("[POWER] blocked-notify stderr: " + text.trim());
            }
        }
        onExited: code => {
            if (code !== 0)
                console.log("[POWER] blocked-notify failed, gdbus exit " + code);
        }
    }

    function probeBlockersThenNotify() {
        powerMenu.notifyAfterProbe = true;
        notifyWatchdog.restart();
        if (!inhibitProbe.running)
            inhibitProbe.running = true;
    }

    Timer {
        id: notifyWatchdog
        interval: 1500
        onTriggered: {
            if (powerMenu.notifyAfterProbe) {
                powerMenu.notifyAfterProbe = false;
                powerMenu.notifyBlocked();
            }
        }
    }

    function probeBlockers() {
        if (!inhibitProbe.running)
            inhibitProbe.running = true;
    }
    function blockersDump() {
        return JSON.stringify(powerMenu.blockInhibitors);
    }

    property var graceful: null
    readonly property int gracefulTermMs: 6000
    readonly property int gracefulKillMs: 10000

    property int blockersFreshAt: 0

    property string pendingForceOp: ""

    function requestGracefulForce(op) {
        powerMenu.pendingForceOp = op;
        forceWatchdog.restart();

        if (powerMenu.myUid < 0 && !uidProc.running)
            uidProc.running = true;
        if (!inhibitProbe.running)
            inhibitProbe.running = true;
    }

    function resolveForce(fresh) {
        const op = powerMenu.pendingForceOp;
        powerMenu.pendingForceOp = "";
        forceWatchdog.stop();
        if (op === "")
            return;

        powerMenu.graceful = null;
        gracefulTick.stop();
        if (!fresh) {
            powerMenu.forceFallback(op);
            return;
        }
        if (powerMenu.blockInhibitors.length === 0) {
            powerMenu.run(op === "reboot" ? "systemctl reboot" : "systemctl poweroff");
            return;
        }
        if (powerMenu.gracefulForce(op))
            return;
        powerMenu.forceFallback(op);
    }

    function forceFallback(op) {
        powerMenu.pendingOp = op;

        if (actionProc.running) {
            console.log("[POWER] fallback in flight, drop: " + op);
            return;
        }
        actionProc.command = ["bash", "-c", op === "reboot" ? "systemctl reboot -i" : "systemctl poweroff -i"];
        actionProc.running = true;
    }

    function gracefulForce(op) {
        const pids = [];
        for (const b of powerMenu.blockInhibitors)
            if (b.pid > 0 && b.uid >= 0 && b.uid === powerMenu.myUid)
                pids.push(b.pid);
        if (pids.length === 0)
            return false;

        powerMenu.pendingOp = op;
        powerMenu.graceful = {
            op: op,
            phase: "term",
            started: Date.now()
        };
        gracefulKill("TERM", pids);
        gracefulTick.restart();
        return true;
    }

    function gracefulKill(sig, pids) {
        const cmd = ["bash", "-c", "kill -" + sig + " " + pids.join(" ") + " 2>/dev/null; true"];

        const p = sig === "TERM" ? termProc : killProc;
        if (!p.running) {
            p.command = cmd;
            p.running = true;
        }
    }

    function gracefulEvaluate() {
        const g = powerMenu.graceful;
        if (!g)
            return;
        if (!powerMenu.hasBlockers) {
            powerMenu.graceful = null;
            gracefulTick.stop();
            powerMenu.run(g.op === "reboot" ? "systemctl reboot" : "systemctl poweroff");
            return;
        }
        const elapsed = Date.now() - g.started;
        if (g.phase === "term" && elapsed >= powerMenu.gracefulTermMs) {
            g.phase = "kill";

            if (powerMenu.blockersFreshAt >= g.started) {
                const pids = [];
                for (const b of powerMenu.blockInhibitors)
                    if (b.pid > 0 && b.uid >= 0 && b.uid === powerMenu.myUid)
                        pids.push(b.pid);
                if (pids.length > 0)
                    gracefulKill("KILL", pids);
            }
        }
        if (elapsed >= powerMenu.gracefulKillMs) {
            powerMenu.graceful = null;
            gracefulTick.stop();
            powerMenu.notifyBlocked();
            return;
        }
        gracefulTick.restart();
    }

    Timer {
        id: gracefulTick
        interval: 700
        onTriggered: {
            if (!powerMenu.graceful)
                return;
            powerMenu.gracefulEvaluate();
            if (powerMenu.graceful && !inhibitProbe.running)
                inhibitProbe.running = true;
        }
    }

    Timer {
        id: forceWatchdog
        interval: 1500
        onTriggered: {
            if (powerMenu.pendingForceOp !== "")
                powerMenu.resolveForce(false);
        }
    }

    Process {
        id: termProc
        running: false
    }

    Process {
        id: killProc
        running: false
    }

    function run(cmd) {
        close();
        if (String(cmd).indexOf("systemctl poweroff") === 0 || String(cmd).indexOf("systemctl reboot") === 0) {
            powerMenu.pendingOp = String(cmd).indexOf("systemctl reboot") === 0 ? "reboot" : "poweroff";

            if (actionProc.running) {
                console.log("[POWER] action still in flight, drop: " + cmd);
                return;
            }
            actionProc.command = ["bash", "-c", cmd];
            actionProc.running = true;
            return;
        }
        Quickshell.execDetached(["bash", "-c", cmd]);
    }

    Process {
        id: actionProc
        onExited: code => {
            if (code === 0)
                return;
            powerMenu.probeBlockersThenNotify();
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.5)

        SafeMouseArea {
            anchors.fill: parent
            onClicked: powerMenu.close()
        }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: buttonRow.implicitWidth + 48
        height: powerMenu.hasBlockers ? 232 : 208
        radius: 16
        color: Style.card
        border.width: 1
        border.color: Style.border

        MouseArea {
            anchors.fill: parent
        }

        Text {
            visible: powerMenu.hasBlockers
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 14
            width: parent.width - 36
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight

            textFormat: Text.PlainText

            text: I18n.t("power.inhibitMenu") + powerMenu.blockerNames
            color: Style.danger
            font.family: Style.cjk
            font.pixelSize: 13
        }

        focus: true
        Keys.onEscapePressed: powerMenu.close()

        Keys.onPressed: event => {
            if (event.modifiers !== Qt.NoModifier || event.isAutoRepeat)
                return;
            for (let i = 0; i < buttonRow.children.length; i++) {
                const b = buttonRow.children[i];
                if (b.modelData && String(b.modelData.key).toLowerCase() === String(event.text).toLowerCase()) {
                    powerMenu.run(b.modelData.cmd);
                    event.accepted = true;
                    return;
                }
            }
        }

        Row {
            id: buttonRow
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter

            anchors.verticalCenterOffset: powerMenu.hasBlockers ? 13 : 0
            spacing: 24

            Repeater {

                model: [
                    {
                        icon: "lock.png",
                        labelKey: "power.lock",
                        key: "l",
                        cmd: "quickshell ipc call lock toggle"
                    },
                    {
                        icon: "logout.png",
                        labelKey: "power.logout",
                        key: "e",
                        cmd: "loginctl terminate-user \"$USER\""
                    },
                    {
                        icon: "suspend.png",
                        labelKey: "power.suspend",
                        key: "u",
                        cmd: "systemctl suspend"
                    },
                    {
                        icon: "hibernate.png",
                        labelKey: "power.hibernate",
                        key: "h",
                        cmd: "systemctl hibernate"
                    },
                    {
                        icon: "shutdown.png",
                        labelKey: "power.shutdown",
                        key: "s",
                        cmd: "systemctl poweroff"
                    },
                    {
                        icon: "reboot.png",
                        labelKey: "power.reboot",
                        key: "r",
                        cmd: "systemctl reboot"
                    }
                ]

                delegate: Item {
                    id: btn
                    required property var modelData
                    width: 104
                    height: 144

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: btnMouse.containsMouse ? Style.hover : "transparent"
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 10

                        Item {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 60
                            height: 60

                            Image {
                                id: iconImg
                                anchors.fill: parent
                                source: WallpaperMap.fileUrl(powerMenu.iconDir + "/" + btn.modelData.icon)
                                fillMode: Image.PreserveAspectFit
                                mipmap: true
                                visible: false
                            }

                            MultiEffect {
                                anchors.fill: parent
                                source: iconImg
                                colorization: 1.0
                                colorizationColor: Style.text1
                                autoPaddingEnabled: false
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: I18n.t(btn.modelData.labelKey)
                            color: Style.text1
                            font.family: Style.cjk
                            font.pixelSize: 16
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: keyText.implicitWidth + 10
                            height: 16
                            radius: 4

                            color: Qt.rgba(1, 1, 1, 0.10)

                            Text {
                                id: keyText
                                anchors.centerIn: parent
                                text: String(btn.modelData.key).toUpperCase()
                                color: Style.text2
                                font.family: Style.nerd
                                font.pixelSize: 12
                            }
                        }
                    }

                    SafeMouseArea {
                        id: btnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: powerMenu.run(btn.modelData.cmd)
                    }
                }
            }
        }
    }
}
