import QtQuick

Item {
    id: wsBtn

    property int wsId: 1

    property string outputName: ""

    readonly property bool niri: Compositor.name === "niri"

    property var ws: null

    readonly property bool focused: wsBtn.niri ? Compositor.workspaceFocused(wsBtn.wsId, wsBtn.outputName) : (wsBtn.ws ? wsBtn.ws.focused : false)
    readonly property bool hasWindows: iconModel.count > 0

    readonly property real contentOpacity: focused ? 1.0 : (hasWindows ? 0.9 : 0.3)

    ListModel {
        id: iconModel
    }

    function refresh() {
        if (!wsBtn.niri)
            wsBtn.ws = Compositor.workspaceForId(wsBtn.wsId);
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
            if (old && (old.title !== t.title || old.class !== t.class))
                iconModel.setProperty(idx, "toplevel", t);
        }
    }

    implicitWidth: Math.max(30, contentRow.implicitWidth + 12)
    implicitHeight: Style.barContentHeight

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.bottom
        height: 2
        color: Qt.rgba(0, 0, 0, 0.18)
        visible: wsBtn.focused
        z: -1
    }

    Rectangle {
        id: wsBg
        anchors.fill: parent
        radius: 8
        color: "transparent"
        border.width: wsBtn.focused ? 1.5 : 0

        border.color: "#94a3b8"
        opacity: wsBtn.focused ? 1.0 : (wsBtn.hasWindows ? 0.9 : 0.3)
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Style.border
        opacity: 0.16
        visible: wsBtn.hasWindows && !wsBtn.focused
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
        }

        Repeater {
            model: iconModel
            delegate: Item {
                width: 18
                height: 24
                opacity: wsBtn.contentOpacity

                WindowIcon {
                    anchors.centerIn: parent
                    iconSize: 18
                    toplevel: model.toplevel
                }
            }
        }
    }

    MouseArea {
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
            "moveoutofgroup": true
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

    onOutputNameChanged: wsBtn.scheduleRefresh()
    Component.onCompleted: wsBtn.refresh()
}
