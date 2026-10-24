import QtQuick
import Quickshell

Module {
    id: noNetModule

    required property var qsRoot
    required property var wifiModule
    required property var wiredModule

    shown: !wifiModule.wifiPresent && !wiredModule.wiredPresent
    bgColor: "transparent"
    radius: 5
    padLeft: 0
    padRight: 0
    marginRight: 5
    contentYOffset: 1
    contentWidth: noNetGlyph.implicitWidth

    Text {
        id: noNetGlyph
        anchors.centerIn: parent
        color: Style.text2
        font.family: Style.nerd
        font.pixelSize: 18

        text: "\u{F092E}"
    }

    onClicked: Quickshell.execDetached(["nm-applet"])

    onRightClicked: qsRoot.netToggle("right-click")
}
