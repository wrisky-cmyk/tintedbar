import QtQuick
import Quickshell
import Quickshell.Widgets

Item {
    id: winIcon

    required property var toplevel

    property var wsBtnRef
    property int iconSize: 18

    readonly property bool pulsing: winIcon.wsBtnRef && winIcon.wsBtnRef.pulseHit(winIcon.toplevel)
    SequentialAnimation on opacity {
        id: pulseAnim
        running: winIcon.pulsing && !winIcon.urgent
        loops: Animation.Infinite
        NumberAnimation {
            to: 0.2
            duration: 280
        }
        NumberAnimation {
            to: 1.0
            duration: 280
        }

        onRunningChanged: if (!pulseAnim.running)
            winIcon.opacity = 1.0
    }

    implicitWidth: winIcon.iconSize
    implicitHeight: winIcon.iconSize

    property string appClass: ""
    readonly property string title: String(toplevel && toplevel.title ? toplevel.title : "")

    readonly property string glyph: Style.glyphFor(winIcon.appClass, winIcon.title)

    property string appIcon: ""

    readonly property bool urgent: toplevel ? toplevel.urgent === true : false
    SequentialAnimation on opacity {
        id: urgentAnim
        running: winIcon.urgent && !winIcon.pulsing
        loops: Animation.Infinite
        alwaysRunToEnd: false
        NumberAnimation {
            to: 0.25
            duration: 140
        }
        NumberAnimation {
            to: 1.0
            duration: 140
        }

        onRunningChanged: if (!urgentAnim.running)
            winIcon.opacity = 1.0
    }
    property int retries: 0

    function updateClass() {
        const t = winIcon.toplevel;
        if (!t || typeof t !== "object") {
            winIcon.appClass = "";
            return;
        }

        if (t.wayland && t.wayland.appId) {
            winIcon.appClass = String(t.wayland.appId);
        } else {
            const obj = t.lastIpcObject;
            const c = obj ? (obj["class"] || obj["initialClass"] || "") : "";
            winIcon.appClass = String(c || "");
        }
        winIcon.refresh();
    }

    function refresh() {
        const ti = Style.titleIcon(winIcon.title);
        winIcon.appliedTitleIcon = ti;
        const names = winIcon.appClass ? Style.appIconNames(winIcon.appClass) : [];

        const all = ti ? [ti].concat(names) : names;
        winIcon.appIcon = all.length > 0 ? all.join(",") : "";

        const key = JSON.stringify(all);
        if (key !== winIcon.iconNamesKey) {
            winIcon.iconNamesKey = key;
            fileIcon.iconNames = all;
        }
        if (Style.debug) {
            console.log("[WSICON] class=" + winIcon.appClass + " appId=" + (toplevel && toplevel.wayland ? toplevel.wayland.appId : "(none)") + " lastKeys=" + JSON.stringify(Object.keys(toplevel && toplevel.lastIpcObject ? toplevel.lastIpcObject : {})) + " iconNames=" + JSON.stringify(names));
        }
    }

    property string iconNamesKey: ""
    property string appliedTitleIcon: ""

    function refreshForTitle() {
        if (Style.titleIcon(winIcon.title) === winIcon.appliedTitleIcon)
            return;
        winIcon.refresh();
    }

    FileIcon {
        id: fileIcon
    }

    IconImage {
        id: iconImg
        anchors.fill: parent
        source: fileIcon.source
        visible: fileIcon.source !== "" && iconImg.status !== Image.Error
    }

    Text {
        anchors.fill: parent
        visible: fileIcon.source === "" || iconImg.status === Image.Error
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: winIcon.glyph
        color: Style.text1
        font.family: Style.nerd
        font.pixelSize: winIcon.iconSize - 4
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            winIcon.refresh();
        }
    }

    Connections {
        target: (Style.compositor !== "niri" && winIcon.toplevel !== null && winIcon.toplevel !== undefined && typeof winIcon.toplevel === "object") ? winIcon.toplevel : null
        function onWaylandHandleChanged() {
            winIcon.updateClass();
        }
        function onLastIpcObjectChanged() {
            winIcon.updateClass();
        }

        function onTitleChanged() {
            winIcon.refreshForTitle();
        }
    }

    Connections {
        target: (Style.compositor !== "niri" && winIcon.toplevel !== null && winIcon.toplevel !== undefined && typeof winIcon.toplevel === "object" && winIcon.toplevel.wayland !== null && winIcon.toplevel.wayland !== undefined && typeof winIcon.toplevel.wayland === "object") ? winIcon.toplevel.wayland : null
        function onAppIdChanged() {
            winIcon.updateClass();
        }
    }

    Timer {
        interval: 400
        repeat: true
        running: winIcon.appClass === "" && winIcon.retries < 10
        onTriggered: {
            winIcon.retries++;

            if (winIcon.retries % 2 === 1 && Style.compositor !== "niri") {
                Compositor.requestToplevelResync("missing-class");
            }
            winIcon.updateClass();
        }
    }

    onAppClassChanged: {
        winIcon.retries = 0;
        winIcon.refresh();
    }

    onToplevelChanged: winIcon.updateClass()

    Component.onCompleted: winIcon.updateClass()

    onAppIconChanged: {
        if (Style.debug)
            console.log("[WSICON] appIcon ->", winIcon.appIcon);
    }
}
