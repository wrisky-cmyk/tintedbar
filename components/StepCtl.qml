import QtQuick

Item {
    id: ctl

    property string labelText: ""
    property int value: 0

    property bool sel: false
    signal step(int delta)

    implicitWidth: inner.implicitWidth + 8
    implicitHeight: inner.implicitHeight + 6

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: ctl.sel ? Style.hover : "transparent"
    }

    Row {
        id: inner
        anchors.centerIn: parent
        spacing: 4

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: ctl.labelText
            color: Style.text3
            font.family: Style.cjk
            font.pixelSize: 13
        }

        Rectangle {
            width: 22
            height: 20
            anchors.verticalCenter: parent.verticalCenter
            radius: 5
            color: minusMouse.containsMouse ? Style.trough : Qt.rgba(1, 1, 1, 0.06)

            Text {
                anchors.centerIn: parent
                text: "−"
                color: Style.text1
                font.family: Style.cjk
                font.pixelSize: 14
            }

            MouseArea {
                id: minusMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: ctl.step(-1)
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 24
            horizontalAlignment: Text.AlignHCenter
            text: ctl.value
            color: Style.text1

            font.family: Style.nerd
            font.pixelSize: 13
        }

        Rectangle {
            width: 22
            height: 20
            anchors.verticalCenter: parent.verticalCenter
            radius: 5
            color: plusMouse.containsMouse ? Style.trough : Qt.rgba(1, 1, 1, 0.06)

            Text {
                anchors.centerIn: parent
                text: "+"
                color: Style.text1
                font.family: Style.cjk
                font.pixelSize: 14
            }

            MouseArea {
                id: plusMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: ctl.step(1)
            }
        }
    }
}
