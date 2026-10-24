import QtQuick
import Quickshell
import Quickshell.Widgets

import Quickshell.Services.SystemTray

Item {
    id: trayModule

    required property var panel
    readonly property alias trayRowItem: trayRow

    readonly property int padLeft: 6
    implicitHeight: Style.barContentHeight

    implicitWidth: trayRow.implicitWidth + trayModule.padLeft + 5

    Row {
        id: trayRow
        x: trayModule.padLeft

        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        property string lastMenuId: ""

        function openMenu(which) {
            for (let i = 0; i < trayRow.children.length; i++) {
                const c = trayRow.children[i];
                if (!c || !c.modelData || !c.modelData.hasMenu)
                    continue;
                if (which && String(c.modelData.id) !== String(which))
                    continue;
                trayRow.lastMenuId = String(c.modelData.id);
                const pos = c.mapToItem(panel.contentItem, 0, 0);
                c.modelData.display(panel, Math.round(pos.x), Math.round(pos.y) + Style.barHeight);
                return true;
            }
            return false;
        }

        function openNextMenu() {
            const cands = [];
            for (let i = 0; i < trayRow.children.length; i++) {
                const c = trayRow.children[i];
                if (c && c.modelData && c.modelData.hasMenu)
                    cands.push(c);
            }
            if (cands.length === 0)
                return false;
            let idx = 0;
            for (let i = 0; i < cands.length; i++)
                if (String(cands[i].modelData.id) === trayRow.lastMenuId)
                    idx = (i + 1) % cands.length;
            return trayRow.openMenu(cands[idx].modelData.id);
        }

        function listItems() {
            const out = [];
            for (let i = 0; i < trayRow.children.length; i++) {
                const c = trayRow.children[i];
                if (!c || !c.modelData)
                    continue;
                out.push({
                    id: String(c.modelData.id),
                    hasMenu: !!c.modelData.hasMenu,
                    title: String(c.modelData.title)
                });
            }
            return JSON.stringify(out);
        }

        Repeater {
            model: SystemTray.items

            delegate: Item {
                id: trayItem
                implicitWidth: 11
                implicitHeight: 18

                property int reloadTries: 0

                required property var modelData

                IconImage {
                    id: trayImg
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    source: trayF.source

                    onStatusChanged: {
                        if (status === Image.Error && trayItem.reloadTries < 3) {
                            reloadTimer.restart();
                        } else if (status === Image.Ready) {
                            trayItem.reloadTries = 0;
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: trayF.source === "" || trayImg.status === Image.Error
                    text: "●"
                    color: Style.text3
                    font.family: Style.cjk
                    font.pixelSize: 10
                }

                FileIcon {
                    id: trayF
                    iconName: modelData.icon
                    onIconNameChanged: trayItem.reloadTries = 0
                }

                Timer {
                    id: reloadTimer
                    interval: 800
                    onTriggered: {
                        if (trayItem.reloadTries >= 3)
                            return;
                        trayItem.reloadTries++;
                        trayF.restart();
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton && modelData.hasMenu) {
                            const pos = trayItem.mapToItem(panel.contentItem, 0, 0);

                            modelData.display(panel, Math.round(pos.x), Math.round(pos.y) + Style.barHeight);
                        } else {
                            modelData.activate();
                        }
                    }
                }
            }
        }
    }
}
