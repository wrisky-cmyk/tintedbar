pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import Quickshell.Io
import "."

OverlayPanel {
    id: picker

    required property var qsRoot

    property string query: ""

    property bool clearArmed: false

    property bool wipePendingReload: false

    property var entries: []

    property bool clipBinMissing: false
    property bool watcherMissing: false
    readonly property string emptyHint: clipBinMissing ? I18n.t("clips.noBin") : watcherMissing ? I18n.t("clips.noStore") + "\nwl-paste --watch cliphist store" : I18n.t("clips.empty")

    readonly property int maxEntries: qsRoot.clipMaxEntries
    readonly property var filtered: {
        const q = picker.query.toLowerCase();
        const out = [];
        for (const e of picker.entries) {
            if (q === "" || e.lower.indexOf(q) >= 0) {
                out.push(e);

                if (out.length >= picker.maxEntries)
                    break;
            }
        }
        return out;
    }

    function previewOf(line) {
        const t = String(line);
        const i = t.indexOf("\t");
        return i >= 0 ? t.substring(i + 1) : t;
    }

    function open() {
        visible = true;
        query = "";
        input.text = "";
        picker.headerSel = 0;

        list.currentIndex = 0;

        if (!clipsLoad.running)
            clipsLoad.running = true;

        picker.clipBinMissing = false;
        picker.watcherMissing = false;

        if (!envProbe.running)
            envProbe.running = true;
        input.forceActiveFocus();
    }
    function close() {
        visible = false;
        picker.clearArmed = false;
    }

    property int headerSel: 0
    readonly property bool showSel: picker.headerSel === 1
    readonly property bool clearSel: picker.headerSel === 2

    function setHeader(n) {
        picker.headerSel = n;

        if (n === 0)
            input.forceActiveFocus();
        else
            card.forceActiveFocus();
    }
    function selUp() {
        if (picker.clearSel)
            return;
        if (picker.showSel) {
            picker.setHeader(2);
            return;
        }
        if (list.currentIndex <= 0) {
            picker.setHeader(1);
            return;
        }
        list.decrementCurrentIndex();
    }
    function selDown() {
        if (picker.clearSel) {
            picker.setHeader(1);
            return;
        }
        if (picker.showSel) {
            picker.setHeader(0);
            list.currentIndex = 0;
            return;
        }
        list.incrementCurrentIndex();
    }

    function adjustSel(d) {
        if (picker.showSel)
            showCtl.step(d);
    }

    function currentRawLine() {
        const i = list.currentIndex;
        if (i < 0 || i >= picker.filtered.length)
            return "";
        return String(picker.filtered[i].raw);
    }

    function pressSel(line) {
        if (picker.clearSel) {
            if (!picker.clearArmed) {
                picker.clearArmed = true;
                clearArmReset.restart();
                return;
            }
            picker.clearArmed = false;
            clearArmReset.stop();
            picker.wipe();
            return;
        }
        if (picker.showSel)
            return;
        picker.pick(line);
    }

    function pick(line) {
        if (!line)
            return;

        if (copyProc.running)
            return;
        close();

        copyProc.command = ["timeout", "15", "bash", "-c", "set -o pipefail; t=$(mktemp) || exit 1; " + "trap 'rm -f \"$t\"' EXIT; " + "printf '%s\\n' " + Style.sq(line) + " | cliphist decode > \"$t\" || exit 1; " + "[ -s \"$t\" ] || exit 1; wl-copy < \"$t\""];
        copyProc.running = true;
    }

    function wipe() {
        if (clipsLoad.running) {
            wipePendingReload = true;
            wipeProc.running = true;
            return;
        }
        picker.entries = [];
        wipeProc.running = true;
    }

    Process {
        id: clipsLoad
        running: false
        command: ["timeout", "15", "cliphist", "list"]

        onExited: {
            if (wipePendingReload) {
                wipePendingReload = false;
                clipsLoad.running = true;
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                if (picker.wipePendingReload)
                    return;
                const out = [];

                const loadCap = 1000;
                for (const l of String(text).split("\n")) {
                    if (l === "")
                        continue;

                    out.push({
                        raw: l,
                        lower: picker.previewOf(l).toLowerCase()
                    });
                    if (out.length >= loadCap)
                        break;
                }
                picker.entries = out;

                list.positionViewAtBeginning();
            }
        }
    }

    Process {
        id: envProbe
        running: false
        command: ["sh", "-c", "command -v cliphist >/dev/null 2>&1 && echo bin=1 || echo bin=0; " + "pgrep -f 'wl-[p]aste' >/dev/null 2>&1 && echo watch=1 || echo watch=0"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = String(text);
                picker.clipBinMissing = t.indexOf("bin=0") >= 0;
                picker.watcherMissing = t.indexOf("watch=0") >= 0;
            }
        }
    }

    Process {
        id: copyProc
        running: false

        onExited: code => {
            if (code !== 0)
                Style.notifySimple(I18n.t("clips.copyFailed"), "");
        }
    }

    Process {
        id: wipeProc
        running: false
        command: ["timeout", "15", "cliphist", "wipe"]

        onExited: exitCode => {
            if (clipsLoad.running)
                picker.wipePendingReload = true;
            else
                clipsLoad.running = true;
        }
    }

    SafeMouseArea {
        anchors.fill: parent
        onClicked: picker.close()
    }

    Rectangle {
        id: card
        width: 560

        readonly property int rowStride: 34
        readonly property int chromeHeight: 64
        height: {
            const raw = Math.max(420, Screen.height - 240);
            return Math.max(420, chromeHeight + Math.floor((raw - chromeHeight) / rowStride) * rowStride);
        }
        anchors.centerIn: parent
        radius: 12
        color: Style.card
        border.width: 1
        border.color: Style.border

        MouseArea {
            anchors.fill: parent
        }

        focus: true
        Keys.onEscapePressed: picker.close()
        Keys.onUpPressed: picker.selUp()
        Keys.onDownPressed: picker.selDown()

        Keys.onLeftPressed: picker.adjustSel(-1)
        Keys.onRightPressed: picker.adjustSel(1)

        Keys.onPressed: event => {
            if (event.key === Qt.Key_PageUp) {
                picker.headerSel = 0;
                list.currentIndex = Math.max(0, list.currentIndex - 10);
                event.accepted = true;
            } else if (event.key === Qt.Key_PageDown) {
                picker.headerSel = 0;
                list.currentIndex = Math.min(Math.max(0, list.count - 1), Math.max(0, list.currentIndex) + 10);
                event.accepted = true;
            } else if (event.key === Qt.Key_Home) {
                picker.headerSel = 0;
                list.currentIndex = 0;
                event.accepted = true;
            } else if (event.key === Qt.Key_End) {
                picker.headerSel = 0;
                list.currentIndex = Math.max(0, list.count - 1);
                event.accepted = true;
            }
        }
        Keys.onReturnPressed: picker.pressSel(picker.currentRawLine())
        Keys.onEnterPressed: picker.pressSel(picker.currentRawLine())

        Column {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            Row {
                id: searchRow
                width: parent.width
                height: 36
                spacing: 8

                Rectangle {
                    width: searchRow.width - showCtl.width - clearBtn.width - searchRow.spacing * 2
                    height: searchRow.height
                    radius: 8
                    color: Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1
                    border.color: Style.border

                    TextInput {
                        id: input
                        anchors.fill: parent
                        anchors.margins: 8
                        verticalAlignment: TextInput.AlignVCenter
                        color: Style.text1
                        font.family: Style.cjk
                        font.pixelSize: 14
                        focus: true
                        clip: true
                        onTextEdited: {
                            picker.query = text;
                            list.currentIndex = 0;
                        }
                        Keys.onUpPressed: picker.selUp()
                        Keys.onDownPressed: picker.selDown()

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Home) {
                                picker.headerSel = 0;
                                list.currentIndex = 0;
                                event.accepted = true;
                            } else if (event.key === Qt.Key_End) {
                                picker.headerSel = 0;
                                list.currentIndex = Math.max(0, list.count - 1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_PageUp) {
                                picker.headerSel = 0;
                                list.currentIndex = Math.max(0, list.currentIndex - 10);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_PageDown) {
                                picker.headerSel = 0;
                                list.currentIndex = Math.min(Math.max(0, list.count - 1), Math.max(0, list.currentIndex) + 10);
                                event.accepted = true;
                            }
                        }
                        Keys.onReturnPressed: picker.pressSel(picker.currentRawLine())
                        Keys.onEnterPressed: picker.pressSel(picker.currentRawLine())
                        Text {
                            anchors.fill: parent
                            visible: input.text === ""
                            text: I18n.t("clips.search")
                            color: Style.text3
                            font.family: Style.cjk
                            font.pixelSize: 14
                        }
                    }
                }

                StepCtl {
                    id: showCtl
                    height: searchRow.height
                    labelText: I18n.t("clips.show")
                    value: picker.qsRoot.clipMaxEntries

                    sel: picker.showSel
                    onStep: d => picker.qsRoot.setClipMaxEntries(picker.qsRoot.clipMaxEntries + d * 10)
                }

                Rectangle {
                    id: clearBtn
                    width: 56
                    height: searchRow.height
                    radius: 8

                    readonly property bool lit: clearMouse.containsMouse || picker.clearSel
                    color: lit ? Style.hover : "transparent"
                    border.width: 1
                    border.color: lit ? Style.danger : Style.border

                    Text {
                        anchors.centerIn: parent
                        text: picker.clearArmed ? I18n.t("clips.clearConfirm") : I18n.t("clips.clear")
                        color: clearBtn.lit ? Style.danger : Style.text3
                        font.family: Style.cjk
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!picker.clearArmed) {
                                picker.clearArmed = true;
                                clearArmReset.restart();
                                return;
                            }
                            picker.clearArmed = false;
                            clearArmReset.stop();
                            picker.wipe();
                        }
                    }
                }

                Timer {
                    id: clearArmReset
                    interval: 2000
                    onTriggered: picker.clearArmed = false
                }
            }

            Item {
                width: parent.width

                height: parent.height - 44

                ListView {
                    id: list
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top

                    height: Math.floor(parent.height / card.rowStride) * card.rowStride
                    clip: true
                    spacing: 2

                    model: picker.visible ? picker.filtered : []
                    currentIndex: 0

                    onCountChanged: {
                        currentIndex = 0;
                        positionViewAtBeginning();
                    }

                    onCurrentIndexChanged: {
                        if (currentIndex >= 0)
                            positionViewAtIndex(currentIndex, ListView.Contain);
                    }

                    delegate: Item {
                        id: row

                        required property int index
                        required property var modelData
                        readonly property string rawLine: String(modelData.raw)

                        width: list.width
                        height: 32

                        Rectangle {
                            anchors.fill: parent
                            radius: 6

                            color: (rowMouse.containsMouse || (list.currentIndex === row.index && picker.headerSel === 0)) ? Style.hover : "transparent"
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            text: picker.previewOf(row.rawLine)
                            textFormat: Text.PlainText
                            color: Style.text2
                            font.family: Style.cjk
                            font.pixelSize: 13
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        SafeMouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: picker.pick(row.rawLine)
                        }
                    }
                }

                ThinScrollBar {
                    target: list
                    anchors.top: list.top
                    anchors.bottom: list.bottom
                    anchors.right: list.right
                    anchors.rightMargin: -10
                }

                Text {
                    anchors.centerIn: parent
                    visible: picker.filtered.length === 0
                    text: picker.entries.length !== 0 ? I18n.t("clips.noMatch") : picker.emptyHint
                    color: Style.text3
                    font.family: Style.cjk
                    font.pixelSize: 13
                }
            }
        }
    }
}
