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

    property real contentWidth: -1

    signal clicked
    signal rightClicked

    implicitHeight: Style.barContentHeight
    visible: mod.shown
    implicitWidth: (mod.contentWidth >= 0 ? mod.contentWidth : contentItem.childrenRect.width) + mod.padLeft + mod.padRight + mod.marginLeft + mod.marginRight

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

    property bool hoverTint: true
    Rectangle {
        anchors.fill: bgRect
        radius: mod.radius
        color: "#ffffff"
        opacity: (mouse.containsMouse && mod.hoverTint) ? 0.05 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 100
            }
        }
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
        hoverEnabled: mod.hoverTint
        cursorShape: mod.hoverTint ? Qt.PointingHandCursor : Qt.ArrowCursor

        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: m => {
            if (m.button === Qt.RightButton)
                mod.rightClicked();
            else
                mod.clicked();
        }

        onWheel: ev => {
            if (!mod.wheelEnabled || ev.angleDelta.y === 0)
                return;
            mod.wheelAccum += ev.angleDelta.y;
            while (Math.abs(mod.wheelAccum) >= 120) {
                const dir = mod.wheelAccum > 0 ? 1 : -1;
                mod.wheelAccum -= dir * 120;
                mod.wheelNotch(dir);
            }
        }
    }

    property bool wheelEnabled: false
    property real wheelAccum: 0
    signal wheelNotch(int d)
}
