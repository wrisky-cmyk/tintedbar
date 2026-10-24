import QtQuick
import Quickshell
import Quickshell.Io

Module {
    id: netSpeedModule

    required property var qsRoot

    shown: qsRoot.showNetSpeed && (netSpeedModule.wifi !== null || netSpeedModule.wired !== null)
    bgColor: "transparent"
    radius: 5
    padLeft: 0
    padRight: 4
    contentYOffset: 1
    contentWidth: netSpeedMetrics.advanceWidth

    readonly property var wifi: Style.connectedWifi()
    readonly property var wired: Style.connectedWired()
    property real rxSpeed: 0
    property real txSpeed: 0
    property var lastBytes: null

    function fmtSpeed(v) {
        v = Math.max(0, v);
        let n, u;
        if (v >= 1073741824) {
            n = v / 1073741824;
            u = "G";
        } else if (v >= 1048576) {
            n = v / 1048576;
            u = "M";
        } else if (v >= 1024) {
            n = v / 1024;
            u = "K";
        } else {
            n = v;
            u = "B";
        }
        n = Math.min(999, Math.round(n));
        return ("00" + n).slice(-3) + u;
    }

    function refreshSpeed(text) {
        let rx = 0, tx = 0, seen = 0;
        for (const l of String(text).split("\n").slice(2)) {
            const f = l.trim().split(/[:\s]+/);
            if (f.length < 10 || f[0] === "" || f[0] === "lo")
                continue;
            rx += +f[1] || 0;
            tx += +f[9] || 0;
            seen++;
        }

        if (seen === 0)
            return;
        const now = Date.now();
        if (lastBytes) {
            const dt = (now - lastBytes.t) / 1000;
            if (dt > 0) {
                rxSpeed = Math.max(0, (rx - lastBytes.rx) / dt);
                txSpeed = Math.max(0, (tx - lastBytes.tx) / dt);
            }
        }
        lastBytes = {
            rx: rx,
            tx: tx,
            t: now
        };
    }

    FileView {
        id: netFile
        path: "/proc/net/dev"
        blockLoading: true
        printErrors: false
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (!qsRoot.showNetSpeed)
                return;

            if (netSpeedModule.wifi === null && netSpeedModule.wired === null)
                return;
            netFile.reload();
            netSpeedModule.refreshSpeed(netFile.text());
        }
    }

    TextMetrics {
        id: netSpeedMetrics
        font.family: Style.nerd
        font.pixelSize: 14
        text: "↓000B ↑000B"
    }

    Text {
        id: netSpeedText
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 1

        width: netSpeedMetrics.advanceWidth
        horizontalAlignment: Text.AlignRight
        color: Style.text2
        font.family: Style.nerd
        font.pixelSize: 14
        text: "↓" + netSpeedModule.fmtSpeed(netSpeedModule.rxSpeed) + " ↑" + netSpeedModule.fmtSpeed(netSpeedModule.txSpeed)
    }

    onClicked: Quickshell.execDetached(["nm-applet"])
    onRightClicked: qsRoot.netToggle("right-click")
}
