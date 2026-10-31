import QtQuick
import QtQuick.Window
import Quickshell.Services.Notifications
import Quickshell.Widgets

Item {
    id: panel

    property var center: null
    property int panelWidth: 360
    property int rowHeight: 54
    property int maxTitleLines: 2
    property int maxBodyLines: 3

    readonly property int listHeightCap: Math.max(380, Screen.height - 240)

    readonly property real listHeight: {
        const total = entries.implicitHeight + 0 * panel.entryCount;
        const cap = panel.listHeightCap;
        if (total <= cap)
            return total;
        const kids = entries.children;
        let h = 0;
        for (let i = 0; i < kids.length; i++) {
            const k = kids[i];
            if (!k || k.visible === false || k.height <= 0)
                continue;
            const next = h <= 0 ? k.height : h + entries.spacing + k.height;
            if (next > cap)
                break;
            h = next;
        }
        return h > 0 ? h : cap;
    }

    readonly property bool listOverflows: entries.implicitHeight > panel.listHeight + 1

    readonly property int entryCount: panel.center ? panel.center.history.length : 0

    property int selIndex: 0

    property bool clearArmed: false

    property int _lastCount: 0
    property var _lastTopId: null
    readonly property bool clearSel: panel.selIndex === -1

    onVisibleChanged: {
        if (panel.visible) {
            panel.selIndex = 0;
            panel._lastCount = panel.entryCount;
            panel._lastTopId = panel.topEntryId();
        } else {
            panel.clearArmed = false;
        }
    }

    function topEntryId() {
        const h = panel.center ? panel.center.history : null;
        return h && h.length > 0 && h[0] ? h[0].id : null;
    }

    function syncHistoryState() {
        const count = panel.entryCount;
        const topId = panel.topEntryId();
        if (panel.visible) {
            const grew = count > panel._lastCount;
            const headReplaced = count === panel._lastCount && count > 0 && topId !== panel._lastTopId;

            if (grew || headReplaced) {
                const delta = grew ? count - panel._lastCount : 1;
                if (panel.selIndex >= 0)
                    panel.selIndex += delta;
                list.contentY = 0;
            }
        }
        panel._lastCount = count;
        panel._lastTopId = topId;
        if (count === 0) {
            panel.selIndex = 0;
            return;
        }
        if (panel.selIndex >= count)
            panel.selIndex = Math.max(0, count - 1);
    }

    Connections {
        target: panel.center
        function onHistoryChanged() {
            panel.syncHistoryState();
        }
    }

    function moveSel(d) {
        const n = panel.entryCount;

        if (n === 0)
            return;
        const i = Math.max(-1, Math.min(n - 1, panel.selIndex + d));
        if (i === panel.selIndex)
            return;
        panel.selIndex = i;
        panel.scrollToSel();
    }

    function scrollToSel() {
        if (panel.selIndex < 0)
            return;
        const row = entries.children[panel.selIndex];
        if (!row || !row.height)
            return;
        const top = row.y;
        const bottom = top + row.height;
        if (top < list.contentY)
            list.contentY = top;
        else if (bottom > list.contentY + list.height)
            list.contentY = bottom - list.height;
    }
    function activateSel() {
        if (!panel.center)
            return;
        if (panel.clearSel) {
            if (!panel.clearArmed) {
                panel.clearArmed = true;
                clearArmReset.restart();
                return;
            }
            panel.clearArmed = false;
            clearArmReset.stop();
            panel.center.clearAll();
            return;
        }
        const e = panel.center.history[panel.selIndex];
        if (e)
            panel.center.activateEntry(e);
    }
    function removeSel() {
        if (!panel.center || panel.selIndex < 0)
            return;
        const e = panel.center.history[panel.selIndex];
        if (e)
            panel.center.removeEntry(e.id);
    }

    implicitWidth: panelWidth
    implicitHeight: frame.height

    Rectangle {
        id: frame
        width: panel.panelWidth
        radius: 12
        color: Style.card
        border.width: 1
        border.color: Style.border
        height: layout.implicitHeight + 20

        Column {
            id: layout
            x: 10
            y: 10
            width: frame.width - 20
            spacing: 8

            Item {
                width: layout.width
                height: 24

                Text {
                    id: panelTitle
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("notif.title")
                    color: Style.text1
                    font.family: Style.cjk
                    font.pixelSize: 16
                    font.bold: true
                }

                Text {
                    anchors.left: parent.left

                    anchors.leftMargin: panelTitle.implicitWidth + 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: panel.entryCount
                    visible: panel.entryCount > 0
                    color: Style.text3
                    font.family: Style.cjk
                    font.pixelSize: 13
                }

                Text {
                    id: clearAll

                    anchors.right: closeBtn.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: panel.clearArmed ? I18n.t("notif.clearConfirm") : I18n.t("notif.clearAll")
                    color: clearMouse.containsMouse ? (panel.clearArmed ? Style.privacyRed : Style.text1) : Style.text3
                    font.family: Style.cjk
                    font.pixelSize: 13
                    visible: panel.entryCount > 0

                    Rectangle {
                        z: -1
                        visible: panel.clearSel
                        anchors.fill: parent
                        anchors.margins: -4
                        radius: 5
                        color: Style.hover
                    }

                    SafeMouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!panel.center)
                                return;
                            if (!panel.clearArmed) {
                                panel.clearArmed = true;
                                clearArmReset.restart();
                                return;
                            }
                            panel.clearArmed = false;
                            clearArmReset.stop();
                            panel.center.clearAll();
                        }
                    }
                }

                Timer {
                    id: clearArmReset
                    interval: 2000
                    onTriggered: panel.clearArmed = false
                }

                Text {
                    id: closeBtn
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "✕"
                    color: closeMouse.containsMouse ? Style.text1 : Style.text3
                    font.family: Style.cjk
                    font.pixelSize: 13

                    SafeMouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (panel.center)
                            panel.center.closePanel()
                    }
                }
            }

            Flickable {
                id: list
                width: layout.width
                height: panel.listHeight
                contentHeight: entries.implicitHeight
                clip: true
                visible: panel.entryCount > 0

                Column {
                    id: entries
                    width: list.width
                    spacing: 2

                    Repeater {

                        model: panel.visible && panel.center ? panel.center.history : []

                        delegate: Item {
                            id: row

                            required property int index
                            required property var modelData

                            width: entries.width

                            height: Math.max(panel.rowHeight, 8 + rowTitle.implicitHeight + (rowBody.visible ? 3 + rowBody.implicitHeight : 0) + 8)

                            Rectangle {
                                anchors.fill: parent
                                radius: 8

                                color: index === panel.selIndex ? Style.hover : "transparent"
                            }

                            FileIcon {
                                id: rowIconFile
                                visible: false
                                iconNames: {
                                    const e = row.modelData;
                                    const names = [];
                                    if (e.image)
                                        names.push(e.image);
                                    if (e.appIcon)
                                        names.push(e.appIcon);
                                    if (e.desktopEntry)
                                        names.push(e.desktopEntry);
                                    return names;
                                }
                            }

                            IconImage {
                                id: rowIcon
                                x: 8
                                y: 8
                                width: 22
                                height: 22
                                visible: row.hasIcon && source !== "" && status !== Image.Error
                                source: rowIconFile.source
                            }

                            readonly property bool hasIcon: !!(row.modelData && ((row.modelData.appIcon && row.modelData.appIcon !== "") || (row.modelData.image && row.modelData.image !== "") || (row.modelData.desktopEntry && row.modelData.desktopEntry !== "")))

                            Text {
                                anchors.centerIn: rowIcon
                                visible: row.hasIcon && !rowIcon.visible
                                text: "●"
                                color: Style.text3
                                font.family: Style.cjk
                                font.pixelSize: 9
                            }

                            Text {
                                id: rowTime
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.top: parent.top
                                anchors.topMargin: 9

                                text: {
                                    if (!row.modelData)
                                        return "";
                                    const d = new Date(row.modelData.time);
                                    const now = new Date();
                                    return (d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth() && d.getDate() === now.getDate()) ? Qt.formatTime(d, "HH:mm") : Qt.formatDateTime(d, "MM-dd");
                                }
                                color: Style.text3
                                font.family: Style.nerd
                                font.pixelSize: 12

                                opacity: rowMouse.containsMouse ? 0 : 1
                            }

                            Text {
                                id: rowRemove
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.top: parent.top
                                anchors.topMargin: 9
                                z: 1
                                text: "✕"
                                opacity: rowMouse.containsMouse ? 1 : 0
                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 120
                                    }
                                }
                                color: rowMouse.containsMouse ? Style.privacyRed : Style.text3
                                font.family: Style.cjk
                                font.pixelSize: 13

                                SafeMouseArea {
                                    id: rowRemoveMouse
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    hoverEnabled: false
                                    enabled: rowMouse.containsMouse
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (panel.center)
                                        panel.center.removeEntry(row.modelData.id)
                                }
                            }

                            Text {
                                id: rowTitle
                                anchors.left: parent.left
                                anchors.leftMargin: row.hasIcon ? 38 : 10
                                anchors.right: rowTime.left
                                anchors.rightMargin: 8
                                anchors.top: parent.top
                                anchors.topMargin: 8
                                text: row.modelData ? row.modelData.summary : ""
                                color: Style.text1
                                font.family: Style.cjk
                                font.pixelSize: 14
                                font.bold: true
                                wrapMode: Text.Wrap
                                maximumLineCount: panel.maxTitleLines
                                elide: Text.ElideRight
                            }

                            Text {
                                id: rowBody
                                anchors.left: rowTitle.left
                                anchors.right: rowTitle.right
                                anchors.top: rowTitle.bottom
                                anchors.topMargin: 3
                                text: row.modelData ? row.modelData.body : ""
                                visible: text !== ""
                                color: Style.text3
                                font.family: Style.cjk
                                font.pixelSize: 12
                                wrapMode: Text.Wrap
                                elide: Text.ElideRight
                                maximumLineCount: row.modelData && row.modelData.detail === true ? 6 : panel.maxBodyLines
                            }

                            Rectangle {
                                x: 0
                                width: 3
                                height: 26
                                radius: 1.5
                                anchors.verticalCenter: parent.verticalCenter
                                visible: row.modelData ? row.modelData.open === true : false
                                color: Style.notifBorder(row.modelData ? row.modelData.urgency : NotificationUrgency.Normal)
                            }

                            SafeMouseArea {
                                id: rowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                onPositionChanged: if (panel.selIndex !== row.index)
                                    panel.selIndex = row.index
                                onClicked: if (panel.center)
                                    panel.center.activateEntry(row.modelData)
                            }
                        }
                    }
                }
            }

            Item {
                width: layout.width
                height: 56
                visible: panel.entryCount === 0

                Text {
                    anchors.centerIn: parent
                    text: I18n.t("notif.empty")
                    color: Style.text3
                    font.family: Style.cjk
                    font.pixelSize: 13
                }
            }
        }

        Rectangle {
            visible: list.visible && panel.listOverflows
            x: layout.x + list.x + list.width - 4
            width: 3
            radius: 1.5
            color: Style.text3
            opacity: 0.45

            height: entries.implicitHeight > 0 ? Math.max(24, list.height * list.height / entries.implicitHeight) : 24
            y: layout.y + list.y + (list.height - height) * list.contentY / Math.max(1, entries.implicitHeight - list.height)
        }
    }
}
