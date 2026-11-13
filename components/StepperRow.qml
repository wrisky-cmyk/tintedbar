import QtQuick
import "."

Rectangle {
    id: srow
    property string labelText: ""
    property int value: 0
    property var apply: null
    property int step: 1
    property int minValue: 0
    property int maxValue: 99

    property bool offAtZero: false

    property bool sel: false
    function press() {
    }
    function adjust(d) {
        if (srow.apply)
            srow.apply(Math.max(srow.minValue, Math.min(srow.maxValue, srow.value + d * srow.step)));
    }
    width: parent ? parent.width : 228
    height: 32
    radius: 8
    color: (stepMouse.containsMouse || srow.sel) ? Style.hover : "transparent"

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: srow.labelText
        color: Style.text2
        font.family: Style.cjk
        font.pixelSize: 14
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Rectangle {
            width: 22
            height: 20
            radius: 5
            color: stepMinus.containsMouse ? Style.trough : Qt.rgba(1, 1, 1, 0.06)
            Text {
                anchors.centerIn: parent
                text: "−"
                color: Style.text1
                font.family: Style.cjk
                font.pixelSize: 14
            }
            MouseArea {
                id: stepMinus
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: srow.adjust(-1)
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: (srow.offAtZero && srow.value === 0) ? I18n.t("common.off") : srow.value
            color: Style.text1

            font.family: (srow.offAtZero && srow.value === 0) ? Style.cjk : Style.nerd
            font.pixelSize: 14
            width: 26
            horizontalAlignment: Text.AlignHCenter
        }

        Rectangle {
            width: 22
            height: 20
            radius: 5
            color: stepPlus.containsMouse ? Style.trough : Qt.rgba(1, 1, 1, 0.06)
            Text {
                anchors.centerIn: parent
                text: "+"
                color: Style.text1
                font.family: Style.cjk
                font.pixelSize: 14
            }
            MouseArea {
                id: stepPlus
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: srow.adjust(1)
            }
        }
    }

    MouseArea {
        id: stepMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }
}
