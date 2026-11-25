import QtQuick
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
        return String(n) + u;
    }

    function isVirtualIface(name) {
        return /^(veth|docker|virbr|vnet|podman|cni|cali|flannel|vxlan|br[-0-9])/.test(String(name));
    }

    function isTunnelIface(name) {
        return Style.isTunnelIface(name);
    }

    function refreshSpeed(text) {
        const rows = [];
        for (const l of String(text).split("\n").slice(2)) {
            const f = l.trim().split(/[:\s]+/);
            if (f.length < 10 || f[0] === "" || f[0] === "lo" || netSpeedModule.isVirtualIface(f[0]))
                continue;
            rows.push({
                name: f[0],
                rx: +f[1] || 0,
                tx: +f[9] || 0
            });
        }

        if (rows.length === 0)
            return;
        const hasPhysical = rows.some(r => !netSpeedModule.isTunnelIface(r.name));
        let rx = 0, tx = 0;
        for (const r of rows) {
            if (hasPhysical && netSpeedModule.isTunnelIface(r.name))
                continue;
            rx += r.rx;
            tx += r.tx;
        }
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
            if (!netSpeedModule.qsRoot.showNetSpeed)
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

    TextMetrics {
        id: netSpeedTxMetrics
        font.family: Style.nerd
        font.pixelSize: 14
        text: "↑000B"
    }

    Text {
        id: netSpeedRxText
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 1
        color: Style.text2
        font.family: Style.nerd
        font.pixelSize: 14
        text: "↓" + netSpeedModule.fmtSpeed(netSpeedModule.rxSpeed)
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: netSpeedMetrics.advanceWidth - netSpeedTxMetrics.advanceWidth
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 1
        color: Style.text2
        font.family: Style.nerd
        font.pixelSize: 14
        text: "↑" + netSpeedModule.fmtSpeed(netSpeedModule.txSpeed)
    }

    onClicked: Style.probePanelApp(["nm-applet"])
    onRightClicked: qsRoot.netToggle("right-click")
}
