import QtQuick

Item {
    id: notify

    property var center: null

    property int padH: 3
    property int marginLeft: 0

    property int marginRight: 4
    property int glyphSize: 18
    property real opacityVal: 0.8

    readonly property int dotGap: -3

    readonly property bool dnd: notify.center ? notify.center.dnd === true : false

    readonly property bool hasUnread: notify.center ? notify.center.hasUnread === true : false

    readonly property string glyphBell: "\uf0f3"
    readonly property string glyphBellOff: "\uf1f6"

    signal clicked
    signal rightClicked

    implicitHeight: Style.barContentHeight
    implicitWidth: bellIcon.implicitWidth + notify.padH * 2 + notify.marginLeft + notify.marginRight + (bellDot.visible ? notify.dotGap + bellDot.implicitWidth : 0)

    Text {
        id: bellIcon
        x: notify.marginLeft + notify.padH
        anchors.verticalCenter: parent.verticalCenter
        text: notify.dnd ? notify.glyphBellOff : notify.glyphBell
        color: notify.dnd ? Style.text3 : Style.text1
        font.family: Style.nerd
        font.pixelSize: notify.glyphSize
        opacity: notify.opacityVal
    }

    Text {
        id: bellDot
        x: bellIcon.x + bellIcon.implicitWidth + notify.dotGap
        y: bellIcon.y + 2
        visible: notify.hasUnread
        text: "●"
        color: Style.text1
        font.family: Style.nerd
        font.pixelSize: 8
        font.bold: true
        opacity: notify.opacityVal
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: m => {
            if (m.button === Qt.RightButton)
                notify.rightClicked();
            else
                notify.clicked();
        }
    }
}
