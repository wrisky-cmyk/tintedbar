import QtQuick
import Quickshell
import Quickshell.Io
import "."

OverlayPanel {
    id: picker

    property string query: ""

    property var entries: []

    readonly property int maxEntries: qsRoot.clipMaxEntries
    readonly property var filtered: {
        const q = picker.query.toLowerCase();
        const out = [];
        for (const e of picker.entries)
            if (q === "" || e.lower.indexOf(q) >= 0)
                out.push(e);
        return out.slice(0, picker.maxEntries);
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
        clipsLoad.running = true;
        input.forceActiveFocus();
    }
    function close() {
        visible = false;
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
    function pressSel(line) {
        if (picker.clearSel) {
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
        close();

        copyProc.command = ["bash", "-c", "printf '%s\\n' " + Style.sq(line) + " | cliphist decode | wl-copy"];
        copyProc.running = true;
    }

    function wipe() {
        picker.entries = [];
        wipeProc.running = true;
    }

    Process {
        id: clipsLoad
        running: false
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const l of String(text).split("\n")) {
                    if (l === "")
                        continue;
                    out.push({
                        raw: l,
                        lower: l.toLowerCase()
                    });
                }
                picker.entries = out;

                list.positionViewAtBeginning();
            }
        }
    }

    Process {
        id: copyProc
        running: false
    }

    Process {
        id: wipeProc
        running: false
        command: ["cliphist", "wipe"]

        onExited: exitCode => {
            if (exitCode !== 0)
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
        height: 420
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
        Keys.onReturnPressed: picker.pressSel(list.currentItem ? list.currentItem.rawLine : "")

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
                        Keys.onReturnPressed: picker.pressSel(list.currentItem ? list.currentItem.rawLine : "")
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
                    value: qsRoot.clipMaxEntries

                    sel: picker.showSel
                    onStep: d => qsRoot.setClipMaxEntries(qsRoot.clipMaxEntries + d * 10)
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
                        text: I18n.t("clips.clear")
                        color: clearBtn.lit ? Style.danger : Style.text3
                        font.family: Style.cjk
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: picker.wipe()
                    }
                }
            }

            Item {
                width: parent.width

                height: parent.height - 44

                ListView {
                    id: list
                    anchors.fill: parent
                    clip: true
                    spacing: 2
                    model: picker.filtered
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

                            color: (rowMouse.containsMouse || (list.currentIndex === index && picker.headerSel === 0)) ? Style.hover : "transparent"
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            text: picker.previewOf(row.rawLine)
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

                Text {
                    anchors.centerIn: parent
                    visible: picker.filtered.length === 0
                    text: picker.entries.length === 0 ? I18n.t("clips.empty") : I18n.t("clips.noMatch")
                    color: Style.text3
                    font.family: Style.cjk
                    font.pixelSize: 13
                }
            }
        }
    }
}
