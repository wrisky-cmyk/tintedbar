import QtQuick
import Quickshell

PopupWindow {
    id: brightnessPopup

    required property var panel
    required property var brightnessModule

    visible: false
    function open() {
        if (brightnessModule.backend === "" && !brightnessModule.preview)
            return;

        if (brightnessModule.pct < 0)
            brightnessModule.refresh();
        brightnessPopup.visible = true;
    }
    function close() {
        brightnessPopup.visible = false;
    }

    color: "transparent"
    implicitWidth: 224
    implicitHeight: 48 + Style.barHeight + 2 - Style.barInset
    grabFocus: true
    anchor.window: panel
    anchor.item: brightnessModule
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Top

    Rectangle {
        id: brCard
        anchors.fill: parent

        anchors.topMargin: Style.barHeight + 2 - Style.barInset
        radius: 12
        color: Style.card
        border.width: 1
        border.color: Style.border
        focus: true
        Keys.onEscapePressed: brightnessPopup.close()

        property bool dragging: false
        property int dragPct: 0
        property int lastX: -1
        property real wheelAccum: 0

        function setFromX(px) {
            lastX = Math.round(px);
            dragPct = Math.round(Math.min(100, Math.max(0, px - brTrough.x) / Math.max(1, brTrough.width) * 100));
        }

        readonly property int shownPct: brCard.dragging ? brCard.dragPct : brightnessModule.pct

        Rectangle {
            id: brTrough
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 150
            height: 5
            radius: 5
            color: Style.trough

            Rectangle {
                width: parent.width * Math.min(1, Math.max(0, brCard.shownPct / 100))
                height: parent.height
                radius: 5
                color: Style.fill
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            x: brTrough.x + brTrough.width + 10
            text: brCard.shownPct < 0 ? "–" : brCard.shownPct + "%"
            color: Style.text2
            font.family: Style.cjk
            font.pixelSize: 14
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton

            onWheel: ev => {
                if (ev.angleDelta.y === 0)
                    return;
                brCard.wheelAccum += ev.angleDelta.y;
                while (Math.abs(brCard.wheelAccum) >= 120) {
                    const dir = brCard.wheelAccum > 0 ? 1 : -1;
                    brCard.wheelAccum -= dir * 120;
                    brightnessModule.stepPct(dir * 5, "popup-wheel");
                }
            }
            onPressed: m => {
                brCard.dragging = true;
                brCard.setFromX(m.x);
            }
            onReleased: m => {
                brCard.dragging = false;

                brightnessModule.setPct(brCard.dragPct, "popup x" + brCard.lastX);
            }
            onCanceled: brCard.dragging = false
            onPositionChanged: m => {
                if (brCard.dragging)
                    brCard.setFromX(m.x);
            }
        }
    }
}
