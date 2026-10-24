import QtQuick
import Quickshell

Module {
    id: wiredModule

    required property var qsRoot
    required property var wifiModule

    readonly property bool hasLink: {
        const d = Style.wiredDevice();
        return d ? !!d.hasLink : false;
    }
    shown: wiredModule.wiredPresent && (wiredModule.hasLink || !wifiModule.wifiPresent)
    bgColor: "transparent"
    radius: 5
    padLeft: 0
    padRight: 0
    marginRight: 5
    contentYOffset: 1
    contentWidth: wiredRow.implicitWidth

    readonly property var wired: Style.connectedWired()

    readonly property bool wiredPresent: Style.wiredDevice() !== null

    Row {
        id: wiredRow
        anchors.centerIn: parent
        spacing: 5

        Text {
            id: wiredGlyph
            color: wiredModule.wired ? Style.text2 : Style.text3
            font.family: Style.nerd
            font.pixelSize: 18
            text: wiredModule.wired ? "\u{F0200}" : "\u{F0202}"
        }

        Text {
            id: wiredNameText
            visible: qsRoot.showNetIface && wiredModule.wired !== null
            anchors.verticalCenter: parent.verticalCenter
            color: Style.text2
            font.family: Style.nerd
            font.pixelSize: 14
            text: wiredModule.wired ? wiredModule.wired.name : ""
        }
    }

    onClicked: Quickshell.execDetached(["nm-applet"])

    onRightClicked: qsRoot.netToggleWired("right-click")
}
