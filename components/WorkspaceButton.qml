import QtQuick

Item {
    id: wsBtn

    property int wsId: 1

    property string outputName: ""

    property var pulseTops: []

    function pulseHit(t) {
        if (!t)
            return false;
        for (const p of pulseTops) {
            if (wsBtn.sameToplevel(p, t))
                return true;
        }
        return false;
    }
    function sameToplevel(a, b) {
        if (!a || !b)
            return false;
        if (a.__wid !== undefined && b.__wid !== undefined)
            return String(a.__wid) === String(b.__wid);
        return a === b;
    }

    readonly property bool niri: Compositor.name === "niri"

    property var ws: null

    readonly property bool focused: wsBtn.niri ? Compositor.workspaceFocused(wsBtn.wsId, wsBtn.outputName) : (wsBtn.ws ? wsBtn.ws.focused : false)
    readonly property bool hasWindows: iconModel.count > 0

    readonly property real contentOpacity: focused ? 1.0 : (hasWindows ? 0.75 : 0.3)

    ListModel {
        id: iconModel
    }

    function refresh() {
        if (!wsBtn.niri)
            wsBtn.ws = Compositor.workspaceForId(wsBtn.wsId);
        if (Style.debug && !wsBtn.niri && !wsBtn.ws) {
            console.log("[WSBTN]", wsBtn.wsId, "workspace 未找到; model=", Compositor.workspacesDump());
        }
        wsBtn.syncWindows();
        if (Style.debug && !wsBtn.niri && wsBtn.ws) {
            console.log("[WSBTN]", wsBtn.wsId, "found, toplevels=" + Compositor.modelValues(wsBtn.ws.toplevels).length);
        }
    }

    function syncWindows() {
        const current = wsBtn.niri ? Compositor.windowsForWorkspace(wsBtn.wsId, wsBtn.outputName) : (wsBtn.ws ? Compositor.modelValues(wsBtn.ws.toplevels) : []);
        const same = (a, b) => wsBtn.niri ? (a && b && a.__wid === b.__wid) : a === b;
        for (let i = iconModel.count - 1; i >= 0; i--) {
            const t = iconModel.get(i).toplevel;
            if (!current.some(c => same(c, t)))
                iconModel.remove(i);
        }
        for (const t of current) {
            let idx = -1;
            for (let i = 0; i < iconModel.count; i++) {
                if (same(iconModel.get(i).toplevel, t)) {
                    idx = i;
                    break;
                }
            }
            if (idx < 0) {
                iconModel.append({
                    toplevel: t
                });
                continue;
            }
            if (!wsBtn.niri)
                continue;

            const old = iconModel.get(idx).toplevel;
            if (old && (old.title !== t.title || old.class !== t.class || old.urgent !== t.urgent))
                iconModel.setProperty(idx, "toplevel", t);
        }
    }

    implicitWidth: Math.max(30, contentRow.implicitWidth + 12)
    implicitHeight: Style.barContentHeight

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: "#ffffff"
        opacity: (wsMouse.containsMouse && !wsBtn.focused) ? 0.06 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 120
            }
        }
    }

    Rectangle {
        id: wsBg
        anchors.fill: parent
        radius: 8
        color: wsBtn.focused ? Style.withAlpha(Style.accent, 0.18) : "transparent"
        border.width: 1
        border.color: wsBtn.focused ? Style.withAlpha(Style.accent, 0.45) : "transparent"
        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }
        Behavior on border.color {
            ColorAnimation {
                duration: 120
            }
        }
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 4

        Text {
            height: 24
            verticalAlignment: Text.AlignVCenter
            text: wsBtn.wsId
            color: Style.text1
            font.family: Style.cjk
            font.pixelSize: 18
            font.weight: Font.Bold
            opacity: wsBtn.contentOpacity
            Behavior on opacity {
                NumberAnimation {
                    duration: 120
                }
            }
        }

        Repeater {
            model: iconModel
            delegate: Item {
                width: 18
                height: 24
                opacity: wsBtn.contentOpacity
                Behavior on opacity {
                    NumberAnimation {
                        duration: 120
                    }
                }

                WindowIcon {
                    anchors.centerIn: parent
                    iconSize: 18
                    toplevel: model.toplevel

                    wsBtnRef: wsBtn
                }
            }
        }
    }

    MouseArea {
        id: wsMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (wsBtn.niri) {
                Compositor.activateWorkspace(wsBtn.wsId, wsBtn.outputName);
                return;
            }
            if (wsBtn.ws) {
                wsBtn.ws.activate();
            } else {
                Compositor.dispatchWorkspace(wsBtn.wsId);
            }
        }
    }

    readonly property var refreshEvents: ({
            "openwindow": true,
            "openwindowv2": true,
            "closewindow": true,
            "closewindowv2": true,
            "movewindow": true,
            "movewindowv2": true,
            "workspace": true,
            "workspacev2": true,
            "createworkspace": true,
            "createworkspacev2": true,
            "destroyworkspace": true,
            "destroyworkspacev2": true,
            "renameworkspace": true,
            "moveworkspace": true,
            "moveworkspacev2": true,
            "focusedmon": true,
            "focusedmonv2": true,
            "urgent": true,
            "fullscreen": true,
            "changefloatingmode": true,
            "pin": true,
            "togglegroup": true,
            "moveintogroup": true,
            "moveoutofgroup": true,
            "changeworkspaceid": true
        })

    property bool refreshQueued: false
    function scheduleRefresh() {
        if (wsBtn.refreshQueued)
            return;
        wsBtn.refreshQueued = true;
        Qt.callLater(function () {
            wsBtn.refreshQueued = false;
            wsBtn.refresh();
        });
    }

    Connections {
        target: wsBtn.niri ? Compositor : null
        function onCompositorUpdated() {
            wsBtn.scheduleRefresh();
        }
    }

    Connections {
        target: wsBtn.niri ? null : Compositor
        function onRawEvent(event) {
            const name = (event && event.name !== undefined) ? String(event.name) : "";
            if (!wsBtn.refreshEvents[name])
                return;
            wsBtn.scheduleRefresh();
        }
    }

    Connections {
        target: wsBtn.niri ? null : Compositor
        function onFocusedWorkspaceChanged() {
            wsBtn.scheduleRefresh();
        }
    }

    Connections {
        target: wsBtn.niri ? null : Compositor
        function onValuesChanged() {
            wsBtn.scheduleRefresh();
        }
    }

    Connections {
        target: (!wsBtn.niri && wsBtn.ws && wsBtn.ws.toplevels) ? wsBtn.ws.toplevels : null
        function onValuesChanged() {
            wsBtn.syncWindows();
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: wsBtn.scheduleRefresh()
    }

    Connections {
        target: Compositor
        function onNotificationPulseReady(keys, fresh, target) {
            wsBtn.pulseTops = [];
            if (!wsBtn.hasWindows)
                return;
            const matched = [];
            for (let i = 0; i < iconModel.count; i++) {
                const t = iconModel.get(i).toplevel;
                if (!t)
                    continue;
                if (target) {
                    if (wsBtn.sameToplevel(t, target))
                        matched.push(t);
                } else if (Compositor.matchKeys(Compositor.toplevelClass(t), keys)) {
                    matched.push(t);
                }
            }
            if (matched.length === 0)
                return;
            if (Style.debug)
                console.log("[PULSE] workspace=" + wsBtn.wsId + " matched=" + matched.length + " target=" + !!target);
            wsBtn.pulseTops = matched;
            pulseClear.restart();
        }
    }
    Timer {
        id: pulseClear
        interval: 3000
        onTriggered: wsBtn.pulseTops = []
    }

    onOutputNameChanged: wsBtn.scheduleRefresh()
    Component.onCompleted: wsBtn.refresh()
}
