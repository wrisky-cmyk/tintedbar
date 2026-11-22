pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

PopupPanel {
    id: wpPopup

    required property var qsRoot

    anchorItem: wallpaperModule
    required property var wallpaperModule

    visible: false

    function open() {
        if (!qsRoot.showWallpaper) {
            Qt.callLater(() => wpPopup.qsRoot.panelSet("wallpaper", false));
            return;
        }
        wpPopup.visible = true;
    }
    function close() {
        wpPopup.visible = false;
    }
    function toggle() {
        wpPopup.visible ? wpPopup.close() : wpPopup.open();
    }

    implicitWidth: 480

    implicitHeight: wpCol.implicitHeight + 20 + Style.barHeight + 2 - Style.barInset

    Rectangle {
        id: wpCard
        anchors.fill: parent
        anchors.topMargin: wpPopup.cardTopMargin
        radius: 12
        color: Style.card
        border.width: 1
        border.color: Style.border
        focus: true
        Keys.onEscapePressed: wpPopup.close()

        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: wpCol
            anchors.fill: parent
            anchors.margins: 10
            spacing: 2

            Text {
                text: I18n.t("panel.wallpaper")
                color: Style.text1
                font.family: Style.cjk
                font.pixelSize: 15
                font.bold: true
                leftPadding: 4
                topPadding: 6
                bottomPadding: 4
            }
            Repeater {
                id: wpRep
                model: {
                    const names = [];
                    for (const s of Quickshell.screens)
                        names.push(String(s.name));
                    names.push("*");
                    return names;
                }
                delegate: Rectangle {
                    id: wpRow
                    required property var modelData
                    required property int index
                    readonly property string screenName: String(modelData)

                    Component.onCompleted: if (index === 0)
                        Qt.callLater(() => {
                            wpInput.forceActiveFocus();
                            wpInput.selectAll();
                        })

                    function serialize(e) {
                        if (!e)
                            return "";
                        if (e.color !== "")
                            return e.color;
                        return e.path + (e.mode && e.mode !== "cover" ? "|" + e.mode : "");
                    }

                    function parseValue() {
                        const t = wpInput.text.trim();
                        const bar = t.lastIndexOf("|");
                        if (bar > 0 && /^(cover|contain|tile)$/.test(t.slice(bar + 1).trim()))
                            return {
                                val: t.slice(0, bar).trim(),
                                mode: t.slice(bar + 1).trim()
                            };
                        return {
                            val: t,
                            mode: "cover"
                        };
                    }
                    function currentMode() {
                        return parseValue().mode;
                    }

                    function cycleMode() {
                        const p = parseValue();
                        const next = p.mode === "cover" ? "contain" : p.mode === "contain" ? "tile" : "cover";
                        wpInput.text = p.val + (next !== "cover" ? "|" + next : "");
                    }

                    readonly property bool rowInvalid: wpPopup.wpWarn[wpRow.screenName] === true

                    width: parent.width
                    height: 30
                    radius: 8
                    color: "transparent"

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 62
                        text: wpRow.screenName
                        color: wpRow.screenName === "*" ? Style.text1 : Style.text2
                        font.family: Style.cjk
                        font.pixelSize: 13
                        elide: Text.ElideMiddle
                    }
                    Rectangle {
                        id: wpBox
                        anchors.left: parent.left
                        anchors.leftMargin: 74
                        anchors.right: wpModeBtn.left
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        height: 24
                        radius: 6
                        color: Style.trough

                        border.width: wpInput.activeFocus || wpRow.rowInvalid ? 1 : 0
                        border.color: wpRow.rowInvalid ? Style.danger : Style.accent
                        TextInput {
                            id: wpInput
                            anchors.fill: parent
                            anchors.margins: 5
                            text: wpRow.serialize(WallpaperMap.entries[wpRow.screenName])
                            color: Style.text1
                            font.family: Style.cjk
                            font.pixelSize: 13
                            clip: true
                            selectByMouse: true

                            onTextChanged: {
                                wpPopup.wpState[wpRow.screenName] = wpInput.text;
                                probeDebounce.restart();
                            }

                            onEditingFinished: wpPopup.writeWallpaperConf()
                        }
                    }
                    Rectangle {
                        id: wpModeBtn
                        anchors.right: wpClearBtn.left
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        width: 46
                        height: 24
                        radius: 6
                        color: wpModeMouse.containsMouse ? Style.hover : Style.trough
                        Text {
                            anchors.centerIn: parent
                            text: I18n.t("wp." + wpRow.currentMode())
                            color: Style.text2
                            font.family: Style.cjk
                            font.pixelSize: 12
                        }
                        MouseArea {
                            id: wpModeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                wpRow.cycleMode();
                                wpPopup.writeWallpaperConf();
                            }
                        }
                    }
                    Rectangle {
                        id: wpClearBtn
                        anchors.right: parent.right

                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 24
                        radius: 6
                        color: wpClearMouse.containsMouse ? Style.hover : Style.trough
                        Text {
                            anchors.centerIn: parent
                            text: I18n.t("wp.reset")
                            color: Style.text2
                            font.family: Style.cjk
                            font.pixelSize: 12
                        }
                        MouseArea {
                            id: wpClearMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                wpInput.text = "";
                                wpPopup.writeWallpaperConf();
                            }
                        }
                    }

                    Component.onDestruction: delete wpPopup.wpState[wpRow.screenName]
                }
            }

            Text {
                visible: wpPopup.invalidCount > 0
                text: I18n.t("wp.pathWarn")
                color: Style.danger
                font.family: Style.cjk
                font.pixelSize: 12
                leftPadding: 4
                topPadding: 4
            }
        }
    }

    property var wpState: ({})

    property var wpWarn: ({})
    readonly property int invalidCount: Object.values(wpWarn).filter(Boolean).length

    Timer {
        id: probeDebounce
        interval: 200
        onTriggered: wpPopup.probeAll()
    }

    function probeAll() {
        const keys = [], paths = [];
        for (const name in wpState) {
            const s = String(wpState[name]).trim();
            if (s === "" || s === "~" || s.startsWith("#"))
                continue;
            const bar = s.lastIndexOf("|");
            let p = bar > 0 && /^(cover|contain|tile)$/.test(s.slice(bar + 1).trim()) ? s.slice(0, bar).trim() : s;
            if (p === "")
                continue;
            const abs = p.startsWith("~/") ? Style.home + p.slice(1) : p;
            keys.push(name);
            paths.push(abs);
        }
        probeProc.pendingKeys = keys;
        probeProc.pendingPaths = paths;
        if (probeProc.running) {
            probeProc.queued = true;
            return;
        }
        probeProc.command = ["sh", "-c", 'while IFS= read -r p; do [ -e "$p" ] && echo 1 || echo 0; done', "sh"];
        probeProc.stdinEnabled = true;
        probeProc.running = true;
    }

    Process {
        id: probeProc
        running: false
        property var pendingKeys: []
        property var pendingPaths: []
        property bool queued: false
        stdinEnabled: true
        onStarted: {
            for (const p of pendingPaths)
                probeProc.write(p + "\n");
            probeProc.stdinEnabled = false;
        }
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const flags = String(text).trim().split("\n");
                const warn = {};
                for (let i = 0; i < probeProc.pendingKeys.length; i++)
                    warn[probeProc.pendingKeys[i]] = flags[i] !== "1";
                wpPopup.wpWarn = warn;
                if (probeProc.queued) {
                    probeProc.queued = false;
                    wpPopup.probeAll();
                }
            }
        }
    }

    function writeWallpaperConf() {
        const lines = [];
        for (const name in wpState) {
            const v = String(wpState[name]).trim();
            if (v !== "")
                lines.push(name + "=" + v);
        }
        wpWrite.pendingContent = lines.length ? lines.join("\n") + "\n" : "";

        if (wpWrite.running) {
            wpWrite.queued = true;
            return;
        }
        wpWrite.command = ["bash", Style.configDir + "/scripts/atomic-write.sh", WallpaperMap.confPath];
        wpWrite.stdinEnabled = true;
        wpWrite.running = true;
    }

    Process {
        id: wpWrite
        running: false
        property string pendingContent: ""
        property bool queued: false
        stdinEnabled: true
        onStarted: {
            wpWrite.write(wpWrite.pendingContent);
            wpWrite.stdinEnabled = false;
        }
        onExited: code => {
            if (code !== 0)
                Style.notifySimple(I18n.t("wp.writeFailed"), "");
            if (wpWrite.queued) {
                wpWrite.queued = false;
                wpPopup.writeWallpaperConf();
            }
        }
    }
}
