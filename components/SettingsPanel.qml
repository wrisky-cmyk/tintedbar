import QtQuick
import Quickshell
import "."

OverlayPanel {
    id: settings

    required property var qsRoot
    required property var notifCenter

    function flagsIn(group) {
        const out = [];
        for (const f of (qsRoot.barFlagList || []))
            if (f.group === group && f.hidden !== true)
                out.push(f);
        return out;
    }
    readonly property var displayFlags: flagsIn("display")
    readonly property var notifFlags: flagsIn("notif")
    readonly property var moduleFlags: flagsIn("module")

    readonly property var idleFlags: flagsIn("idle")

    readonly property string repoUrl: "https://github.com/wrisky-cmyk/tintedbar"

    function open() {
        visible = true;
        card.clearSel();
        card.forceActiveFocus();
    }
    function close() {
        visible = false;
        card.clearSel();
    }
    function toggle() {
        visible ? close() : open();
    }

    component Switch: Rectangle {
        id: sw
        property bool checked: false
        width: 36
        height: 18
        radius: 9
        color: sw.checked ? Style.accent : Style.trough
        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: sw.checked ? parent.width - width - 2 : 2
            width: 14
            height: 14
            radius: 7
            color: Style.text1
            Behavior on x {
                NumberAnimation {
                    duration: 120
                }
            }
        }
    }

    component ToggleRow: Rectangle {
        id: trow
        property string labelText: ""
        property bool value: false
        property var toggleFn: null

        property bool sel: false
        function press() {
            if (trow.toggleFn)
                trow.toggleFn();
        }
        function adjust(d) {
            press();
        }
        width: parent ? parent.width : 228
        height: 32
        radius: 8
        color: (rowMouse.containsMouse || trow.sel) ? Style.hover : "transparent"
        readonly property bool checked: trow.value

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: trow.labelText
            color: Style.text2
            font.family: Style.cjk
            font.pixelSize: 14
        }

        Switch {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            checked: trow.checked
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (trow.toggleFn)
                trow.toggleFn()
        }
    }

    component StepperRow: Rectangle {
        id: srow
        property string labelText: ""
        property int value: 0
        property var apply: null
        property int step: 1
        property int minValue: 0
        property int maxValue: 99

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
                    onClicked: srow.apply(Math.max(srow.minValue, srow.value - srow.step))
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: srow.value
                color: Style.text1
                font.family: Style.nerd
                font.pixelSize: 14
                width: 22
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
                    onClicked: srow.apply(Math.min(srow.maxValue, srow.value + srow.step))
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

    component GroupHeader: Text {
        color: Style.text1
        font.family: Style.cjk
        font.pixelSize: 15
        font.bold: true
        leftPadding: 4
        topPadding: 6
        bottomPadding: 4
    }

    component ChoiceRow: Rectangle {
        id: crow
        property string labelText: ""
        property string valueText: ""

        property color valueColor: Style.text1
        property var activate: null

        property bool sel: false
        function press() {
            if (crow.activate)
                crow.activate();
        }
        function adjust(d) {
            press();
        }
        width: parent ? parent.width : 228
        height: 32
        radius: 8
        color: (choiceMouse.containsMouse || crow.sel) ? Style.hover : "transparent"

        Text {
            id: choiceLabel
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: crow.labelText
            color: Style.text2
            font.family: Style.cjk
            font.pixelSize: 14
        }

        Rectangle {
            id: choiceCapsule
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter

            readonly property real maxW: crow.width - 16 - choiceLabel.implicitWidth - 10
            width: Math.min(choiceVal.implicitWidth, Math.max(maxW, 40)) + 16
            height: 20
            radius: 5
            color: Qt.rgba(1, 1, 1, 0.06)

            Text {
                id: choiceVal
                anchors.centerIn: parent
                width: choiceCapsule.width - 16
                text: crow.valueText
                color: crow.valueColor
                elide: Text.ElideMiddle
                horizontalAlignment: Text.AlignHCenter
                font.family: Style.cjk
                font.pixelSize: 14
            }
        }

        MouseArea {
            id: choiceMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (crow.activate)
                crow.activate()
        }
    }

    SafeMouseArea {
        anchors.fill: parent
        onClicked: settings.close()
    }

    Rectangle {
        id: card
        width: 480
        height: column.implicitHeight + 20
        anchors.top: parent.top
        anchors.topMargin: Style.barHeight + 2
        anchors.right: parent.right
        anchors.rightMargin: 2
        radius: 12
        color: Style.card
        border.width: 1
        border.color: Style.border

        MouseArea {
            anchors.fill: parent
        }

        focus: true
        Keys.onEscapePressed: settings.close()

        property var navRows: []
        property int selIndex: -1

        function collectRows() {
            const out = [];
            const walk = col => {
                for (let i = 0; i < col.children.length; i++) {
                    const c = col.children[i];
                    if (c && typeof c.press === "function")
                        out.push(c);
                }
            };
            walk(leftColumn);
            walk(rightColumn);
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
        function pressSel() {
            const r = navRows[selIndex];
            if (r)
                r.press();
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
        Keys.onReturnPressed: card.pressSel()
        Keys.onEnterPressed: card.pressSel()

        Row {
            id: column
            anchors.fill: parent
            anchors.margins: 10
            spacing: 4

            Column {
                id: leftColumn
                width: 228
                spacing: 2

                GroupHeader {
                    text: I18n.t("panel.general")
                }
                ChoiceRow {
                    labelText: I18n.t("panel.language")
                    valueText: I18n.langName
                    activate: () => qsRoot.cycleLang()
                }

                ChoiceRow {
                    labelText: I18n.t("panel.palette")
                    valueText: I18n.t("palette." + Style.paletteName)
                    activate: () => qsRoot.cyclePalette()
                }
                StepperRow {
                    labelText: I18n.t("panel.barHeight")
                    value: Style.barHeight
                    apply: v => qsRoot.setBarHeight(v)
                    step: 2
                    minValue: 24
                    maxValue: 48
                }

                Repeater {
                    model: settings.displayFlags
                    ToggleRow {
                        required property var modelData
                        labelText: I18n.t(modelData.labelKey)
                        value: qsRoot[modelData.key]
                        toggleFn: () => qsRoot.setBarFlag(modelData.key, !qsRoot[modelData.key])
                    }
                }

                GroupHeader {
                    text: I18n.t("panel.idle")
                }
                Repeater {
                    model: settings.idleFlags
                    ToggleRow {
                        required property var modelData
                        labelText: I18n.t(modelData.labelKey)
                        value: qsRoot[modelData.key]
                        toggleFn: () => qsRoot.setBarFlag(modelData.key, !qsRoot[modelData.key])
                    }
                }

                StepperRow {
                    labelText: I18n.t("panel.idleLock")
                    value: qsRoot.idleLockMinutes
                    apply: v => qsRoot.setIdleLockMinutes(v)
                    step: 1
                    minValue: 0
                    maxValue: 60
                }
                StepperRow {
                    labelText: I18n.t("panel.idleDpms")
                    value: qsRoot.idleDpmsMinutes
                    apply: v => qsRoot.setIdleDpmsMinutes(v)
                    step: 1
                    minValue: 0
                    maxValue: 60
                }

                GroupHeader {
                    text: I18n.t("panel.notifications")
                }
                ToggleRow {
                    labelText: I18n.t("panel.dnd")
                    value: notifCenter.dnd
                    toggleFn: () => {
                        notifCenter.dnd = !notifCenter.dnd;
                    }
                }

                Repeater {
                    model: settings.notifFlags
                    ToggleRow {
                        required property var modelData
                        labelText: I18n.t(modelData.labelKey)
                        value: qsRoot[modelData.key]
                        toggleFn: () => qsRoot.setBarFlag(modelData.key, !qsRoot[modelData.key])
                    }
                }

                StepperRow {
                    labelText: I18n.t("panel.historyLimit")
                    value: notifCenter.historyLimit
                    apply: v => qsRoot.setHistoryLimit(v)
                    step: 5
                    minValue: 5
                    maxValue: 50
                }
            }

            Column {
                id: rightColumn
                width: 228
                spacing: 2

                GroupHeader {
                    text: I18n.t("panel.modules")
                }

                Repeater {
                    model: settings.moduleFlags

                    ToggleRow {
                        required property var modelData
                        labelText: I18n.t(modelData.labelKey)
                        value: qsRoot[modelData.key]
                        toggleFn: () => qsRoot.setBarFlag(modelData.key, !qsRoot[modelData.key])
                    }
                }

                ChoiceRow {
                    labelText: I18n.t("panel.version")
                    function adjust(d) {
                    }
                    activate: () => {
                        Quickshell.execDetached(["xdg-open", settings.repoUrl]);
                        settings.close();
                    }

                    valueText: Style.version + (Style.packedCopy ? "+" + Style.packedFingerprint : "") + (Style.modified ? "≠" : "")
                    valueColor: Style.modified ? Style.danger : Style.text1
                }
            }
        }
    }
}
