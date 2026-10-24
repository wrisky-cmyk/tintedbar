import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "."

OverlayPanel {
    id: launcher

    property string query: ""

    readonly property var appRecords: {
        const out = [];
        for (const app of Style.modelValues(DesktopEntries.applications)) {
            if (!app || !app.name)
                continue;
            const nm = String(app.name);
            out.push({
                app: app,
                name: nm,
                nameLc: nm.toLowerCase(),
                execLc: String(app.execString || "").toLowerCase(),
                key: String(app.id || app.name || "")
            });
        }
        return out;
    }

    function launch(app) {
        if (!app)
            return;
        const key = String(app.id || app.name || "");
        UsageStore.bump(key);

        Style.launchDesktop(key);
        launcher.close();
    }

    function launchFirst() {
        const r = launcher.apps[0];
        if (r)
            launcher.launch(r.app);
    }

    function launchSel() {
        const r = launcher.apps[list.currentIndex];
        if (r)
            launcher.launch(r.app);
        else
            launcher.launchFirst();
    }

    function moveSel(d) {
        const n = launcher.apps.length;
        if (n === 0)
            return;
        const i = Math.max(0, Math.min(n - 1, list.currentIndex + d));
        if (i === list.currentIndex)
            return;
        list.currentIndex = i;
        list.positionViewAtIndex(i, ListView.Contain);
    }

    readonly property var calc: {
        const q = query.trim();
        if (q === "" || !/\d/.test(q) || !/[+\-*/%]/.test(q) || !/^[0-9+\-*/().%\s]+$/.test(q))
            return null;
        try {
            const v = Function("return (" + q + ")")();
            if (typeof v === "number" && isFinite(v))
                return Object.is(v, -0) ? 0 : v;
        } catch (e) {}
        return null;
    }

    function fmtCalc(v) {
        return v.toFixed(10).replace(/(\.\d*?)0+$/, "$1").replace(/\.$/, "");
    }
    function copyCalc() {
        if (calc === null)
            return;
        if (calcCopy.running)
            return;
        calcCopy.command = ["bash", "-c", "printf '%s' " + Style.sq(fmtCalc(calc)) + " | wl-copy"];
        calcCopy.running = true;
        launcher.close();
    }
    Process {
        id: calcCopy
        running: false
    }

    function open() {
        visible = true;
        query = "";
        input.text = "";
        list.currentIndex = 0;
        input.forceActiveFocus();
        if (Style.debug)
            console.log("[LAUNCHER] open(), visible=", visible);
    }

    function close() {
        visible = false;
    }

    readonly property var apps: {
        const usage = UsageStore.usage;
        const q = query.toLowerCase();
        const out = [];
        for (const r of launcher.appRecords) {
            if (q === "" || r.nameLc.indexOf(q) >= 0 || r.execLc.indexOf(q) >= 0)
                out.push(r);
        }

        out.sort((a, b) => {
            const ca = usage[a.key] || 0;
            const cb = usage[b.key] || 0;
            if (ca !== cb)
                return cb - ca;
            return a.name.localeCompare(b.name, "zh");
        });
        return out.slice(0, 40);
    }

    SafeMouseArea {
        anchors.fill: parent
        onClicked: launcher.close()
    }

    Rectangle {
        width: 440
        height: 480
        anchors.centerIn: parent
        radius: 12
        color: Style.card
        border.width: 1
        border.color: Style.border

        MouseArea {
            anchors.fill: parent
        }

        focus: true
        Keys.onEscapePressed: launcher.close()

        Keys.onUpPressed: launcher.moveSel(-1)
        Keys.onDownPressed: launcher.moveSel(1)
        Keys.onReturnPressed: {
            if (input.activeFocus)
                return;
            if (launcher.calc !== null)
                launcher.copyCalc();
            else
                launcher.launchSel();
        }

        Column {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            Rectangle {
                width: parent.width
                height: 36
                radius: 8
                color: Qt.rgba(1, 1, 1, 0.06)
                border.width: 1
                border.color: Style.border

                TextInput {
                    id: input
                    anchors.fill: parent
                    anchors.margins: 8
                    clip: true
                    verticalAlignment: TextInput.AlignVCenter
                    color: Style.text1
                    font.family: Style.cjk
                    font.pixelSize: 14
                    Text {
                        anchors.fill: parent
                        visible: input.text === ""
                        text: I18n.t("launcher.search")
                        color: Style.text3
                        font.family: Style.cjk
                        font.pixelSize: 14
                    }
                    focus: true

                    onTextEdited: {
                        launcher.query = text;
                        list.currentIndex = 0;
                    }

                    Keys.onUpPressed: launcher.moveSel(-1)
                    Keys.onDownPressed: launcher.moveSel(1)
                    onAccepted: launcher.calc !== null ? launcher.copyCalc() : launcher.launchSel()
                }
            }

            Rectangle {
                id: calcRow
                visible: launcher.calc !== null
                width: parent.width
                height: 36
                radius: 8
                color: calcMouse.containsMouse ? Style.hover : Qt.rgba(1, 1, 1, 0.06)

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 120
                    text: "= " + (launcher.calc !== null ? launcher.fmtCalc(launcher.calc) : "")
                    color: Style.accent
                    font.family: Style.nerd
                    font.pixelSize: 15
                    font.bold: true
                    elide: Text.ElideRight
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("calc.copy")
                    color: Style.text3
                    font.family: Style.cjk
                    font.pixelSize: 12
                }
                SafeMouseArea {
                    id: calcMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: launcher.copyCalc()
                }
            }

            ListView {
                id: list
                width: parent.width

                height: parent.height - 44 - (calcRow.visible ? 44 : 0)
                clip: true

                currentIndex: 0
                spacing: 2

                model: launcher.visible ? launcher.apps : []

                delegate: Item {
                    id: row
                    width: list.width
                    height: 40

                    required property int index
                    required property var modelData

                    Rectangle {
                        anchors.fill: parent
                        radius: 6

                        color: index === list.currentIndex ? Style.hover : "transparent"
                    }

                    FileIcon {
                        id: fIcon
                        visible: true

                        iconNames: row.modelData.app.icon ? [row.modelData.app.icon] : []
                    }

                    IconImage {
                        id: appImg
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 24
                        height: 24
                        source: fIcon.source
                        visible: fIcon.source !== "" && status !== Image.Error
                    }

                    Text {
                        anchors.centerIn: appImg
                        visible: !appImg.visible

                        text: Style.glyphFor(row.modelData.name, row.modelData.name) || "●"
                        color: Style.text1
                        font.family: Style.nerd
                        font.pixelSize: 18
                    }

                    Text {
                        anchors.left: appImg.right
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.name
                        color: Style.text1
                        font.family: Style.cjk
                        font.pixelSize: 14
                        elide: Text.ElideRight
                    }

                    SafeMouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onPositionChanged: if (list.currentIndex !== row.index)
                            list.currentIndex = row.index
                        onClicked: launcher.launch(row.modelData.app)
                    }
                }
            }
        }
    }
}
