import QtQuick

Item {
    id: sb

    required property var target
    visible: target.contentHeight > target.height + 1
    width: 14

    readonly property real maxScroll: Math.max(0, target.contentHeight - target.height)

    Rectangle {
        id: thumb

        x: parent.width - 4
        width: 3
        radius: 1.5
        color: Style.text3
        opacity: 0.45

        height: Math.max(24, sb.height * target.height / Math.max(1, target.contentHeight))
        y: sb.maxScroll > 0 ? (target.contentY / sb.maxScroll) * (sb.height - height) : 0
    }

    MouseArea {
        anchors.fill: parent
        preventStealing: true
        cursorShape: Qt.PointingHandCursor
        onPressed: m => seek(m.y)
        onPositionChanged: m => {
            if (pressed)
                seek(m.y);
        }
        function seek(y) {
            if (sb.maxScroll <= 0)
                return;
            const half = thumb.height / 2;
            const track = Math.max(1, sb.height - thumb.height);
            const ty = Math.max(0, Math.min(track, y - half));
            target.contentY = ty / track * sb.maxScroll;
        }
    }
}
