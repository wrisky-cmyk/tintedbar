import QtQuick
import Quickshell
import "."

OverlayPanel {
    id: popup

    required property var moduleRef
    required property var qsRoot

    function open() {
        visible = true;
        card.clearSel();

        card.forceActiveFocus();
    }
    function close() {
        visible = false;
        card.clearSel();
    }

    SafeMouseArea {
        anchors.fill: parent
        onClicked: popup.close()
    }

    Rectangle {
        id: card
        width: 300

        height: col.implicitHeight + 24
        anchors.centerIn: parent
        radius: 12
        color: Style.card
        border.width: 1
        border.color: Style.border

        focus: true
        Keys.onEscapePressed: popup.close()

        property var navRows: []
        property int selIndex: -1
        function collectRows() {
            const out = [];
            for (let i = 0; i < col.children.length; i++) {
                const c = col.children[i];

                if (c && typeof c.press === "function")
                    out.push(c);
            }
            return out;
        }
        function setSel(i) {
            if (navRows.length === 0)
                navRows = collectRows();
            if (navRows.length === 0)
                return;
            i = Math.max(0, Math.min(navRows.length - 1, i));
            for (let k = 0; k < navRows.length; k++)
                navRows[k].sel = (k === i);
            selIndex = i;
        }
        function clearSel() {
            for (let k = 0; k < navRows.length; k++)
                navRows[k].sel = false;
            navRows = [];
            selIndex = -1;
        }
        function adjustSel(d) {
            const r = navRows[selIndex];
            if (r)
                r.adjust(d);
        }

        Keys.onUpPressed: card.setSel(card.selIndex - 1)
        Keys.onDownPressed: card.setSel(card.selIndex + 1)
        Keys.onLeftPressed: card.adjustSel(-1)
        Keys.onRightPressed: card.adjustSel(1)

        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Item {
                width: parent.width
                height: 20

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("panel.pomodoro")
                    color: Style.text1
                    font.family: Style.cjk
                    font.pixelSize: 14
                    font.bold: true
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "✕"
                    color: Style.text3
                    font.family: Style.cjk
                    font.pixelSize: 13

                    SafeMouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: popup.close()
                    }
                }
            }

            StepperRow {
                labelText: I18n.t("panel.pomodoroFocus")
                value: qsRoot.pomodoroFocusMin
                apply: v => qsRoot.setPomodoroFocusMin(v)
                step: 1
            }
            StepperRow {
                labelText: I18n.t("panel.pomodoroBreak")
                value: qsRoot.pomodoroBreakMin
                apply: v => qsRoot.setPomodoroBreakMin(v)
                step: 1
            }
            StepperRow {
                labelText: I18n.t("panel.pomodoroLong")
                value: qsRoot.pomodoroLongMin
                apply: v => qsRoot.setPomodoroLongMin(v)
                step: 5
            }
            StepperRow {
                labelText: I18n.t("panel.pomodoroEvery")
                value: qsRoot.pomodoroLongEvery
                apply: v => qsRoot.setPomodoroLongEvery(v)
                step: 1
            }

            Row {
                width: parent.width
                spacing: 8

                Rectangle {
                    width: (parent.width - 8) / 2
                    height: 32
                    radius: 8
                    color: defMouse.containsMouse ? Style.hover : Qt.rgba(1, 1, 1, 0.06)

                    Text {
                        anchors.centerIn: parent
                        text: I18n.t("pomodoro.reset")
                        color: defMouse.containsMouse ? Style.text1 : Style.text3
                        font.family: Style.cjk
                        font.pixelSize: 13
                    }
                    SafeMouseArea {
                        id: defMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            qsRoot.setPomodoroFocusMin(25);
                            qsRoot.setPomodoroBreakMin(5);
                            qsRoot.setPomodoroLongMin(15);
                            qsRoot.setPomodoroLongEvery(4);
                        }
                    }
                }

                Rectangle {
                    width: (parent.width - 8) / 2
                    height: 32
                    radius: 8
                    color: stopMouse.containsMouse ? Style.hover : Qt.rgba(1, 1, 1, 0.06)

                    Text {
                        anchors.centerIn: parent
                        text: I18n.t("pomodoro.stop")
                        color: stopMouse.containsMouse ? Style.text1 : Style.text3
                        font.family: Style.cjk
                        font.pixelSize: 13
                    }
                    SafeMouseArea {
                        id: stopMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (popup.moduleRef)
                                popup.moduleRef.reset();
                            popup.close();
                        }
                    }
                }
            }
        }
    }
}
