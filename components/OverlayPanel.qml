import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: overlay

    required property var bar

    visible: false
    color: "transparent"
    exclusiveZone: -1

    WlrLayershell.layer: WlrLayer.Overlay
    focusable: visible
    screen: overlay.bar ? overlay.bar.screen : null

    anchors.top: true
    anchors.left: true
    anchors.right: true
    anchors.bottom: true
    implicitWidth: screen ? screen.width : 1280
    implicitHeight: screen ? screen.height : 800
}
