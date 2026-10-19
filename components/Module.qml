import QtQuick

Item {
    id: mod

    property color bgColor: "transparent"
    property int radius: 5
    property int padLeft: 0
    property int padRight: 0
    property int marginLeft: 0
    property int marginRight: 0

    property int contentYOffset: 0
    property real opacityVal: 1.0

    property bool shown: true

    property real contentWidth: 0

    signal clicked
    signal rightClicked

    implicitHeight: Style.barContentHeight
    visible: mod.shown
    implicitWidth: (mod.contentWidth > 0 ? mod.contentWidth : contentItem.childrenRect.width) + mod.padLeft + mod.padRight + mod.marginLeft + mod.marginRight

    default property alias content: contentItem.data

    Rectangle {
        id: bgRect
        x: mod.marginLeft
        y: 0
        width: mod.implicitWidth - mod.marginLeft - mod.marginRight
        height: mod.implicitHeight
        radius: mod.radius
        color: mod.bgColor
        opacity: mod.opacityVal
    }

    Item {
        id: contentItem
        x: mod.marginLeft + mod.padLeft
        y: mod.contentYOffset
        width: bgRect.width - mod.padLeft - mod.padRight
        height: mod.implicitHeight
    }

    MouseArea {
        id: mouse
        x: mod.marginLeft
        y: 0
        width: bgRect.width
        height: mod.implicitHeight
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: m => {
            if (m.button === Qt.RightButton)
                mod.rightClicked();
            else
                mod.clicked();
        }
    }
}
