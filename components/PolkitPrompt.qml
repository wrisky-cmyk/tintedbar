import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "."

OverlayPanel {
    id: prompt

    required property var agent
    property bool active: false
    property bool sessionLocked: false

    readonly property var flow: prompt.agent ? prompt.agent.flow : null
    readonly property bool shown: prompt.active && prompt.flow !== null && !prompt.flow.isCompleted && !prompt.sessionLocked

    visible: prompt.shown
    focusable: prompt.shown

    WlrLayershell.layer: WlrLayer.Overlay

    readonly property bool submitted: prompt.flow !== null && !prompt.flow.isResponseRequired && !prompt.flow.isCompleted
    property bool capsOn: false

    readonly property string errorText: {
        const f = prompt.flow;
        if (!f)
            return "";

        if (f.supplementaryIsError && String(f.supplementaryMessage || "") !== "")
            return String(f.supplementaryMessage);
        return f.failed ? I18n.t("polkit.failed") : "";
    }

    readonly property string placeholder: I18n.t("polkit.password")

    readonly property string infoText: {
        const f = prompt.flow;
        if (!f || f.supplementaryIsError)
            return "";
        return String(f.supplementaryMessage || "");
    }

    function submit() {
        const f = prompt.flow;
        if (!f || prompt.submitted || field.text === "") {
            if (Style.debug)
                console.log("[POLKIT] submit() 被挡: len=" + field.text.length + " submitted=" + prompt.submitted + " hasFlow=" + (f !== null));
            return;
        }
        const v = field.text;
        field.text = "";
        console.log("[POLKIT] submit() 已提交");
        f.submit(v);
    }

    function cancel() {
        const f = prompt.flow;
        if (f)
            f.cancelAuthenticationRequest();
    }

    onShownChanged: if (prompt.shown) {
        field.text = "";
        field.forceActiveFocus();
    }

    Connections {
        target: prompt.flow

        function onIsResponseRequiredChanged() {
            if (prompt.flow && prompt.flow.isResponseRequired) {
                field.text = "";
                field.forceActiveFocus();
            }
        }

        function onAuthenticationFailed() {
            console.log("[POLKIT] 这轮没通过(pam 已重开一轮, 可以再试)");
        }

        function onIsCompletedChanged() {
            const f = prompt.flow;
            if (!f || !f.isCompleted)
                return;

            console.log("[POLKIT] 请求结束: " + (f.isCancelled ? "已取消" : "认证通过"));
        }
    }

    Poller {
        active: prompt.shown
        interval: 3000
        command: ["sh", "-c", "v=; for f in /sys/class/leds/*::capslock/brightness; do " + "[ -e \"$f\" ] || break; read -r v < \"$f\"; break; done; " + "if [ -n \"$v\" ]; then printf 'led %s\\n' \"$v\"; " + (Style.compositor === "niri" ? "else printf 'led 0\\n'; fi" : "else exec hyprctl devices -j; fi")]
        onOutput: text => {
            const t = String(text).trim();
            if (t.indexOf("led ") === 0) {
                prompt.capsOn = t.split(/\s+/)[1] === "1";
                return;
            }
            try {
                const d = JSON.parse(t);
                let caps = false;
                for (const k of (d.keyboards || []))
                    if (k.capsLock === true)
                        caps = true;
                prompt.capsOn = caps;
            } catch (e) {}
        }
    }

    Rectangle {
        id: cardBox
        anchors.centerIn: parent
        width: 430
        implicitHeight: cardColumn.implicitHeight + 48
        height: implicitHeight
        radius: 12

        color: Style.card
        border.width: 1
        border.color: prompt.errorText !== "" ? Style.danger : Qt.rgba(1, 1, 1, 0.10)
        Behavior on border.color {
            ColorAnimation {
                duration: 120
            }
        }

        Keys.onReturnPressed: prompt.submit()
        Keys.onEnterPressed: prompt.submit()
        Keys.onEscapePressed: prompt.cancel()

        Column {
            id: cardColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: 24
            spacing: 14

            Row {
                width: parent.width
                spacing: 10

                FileIcon {
                    id: iconFile
                    iconNames: prompt.flow ? [String(prompt.flow.iconName || "")] : []
                }
                Item {
                    id: iconBox
                    width: 22
                    height: 22
                    anchors.verticalCenter: parent.verticalCenter

                    IconImage {
                        id: iconImg
                        anchors.fill: parent
                        source: iconFile.source
                        visible: iconFile.source !== "" && status !== Image.Error
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !iconBox.iconImgVisible
                        text: "\uF023"
                        color: Style.accent
                        font.family: Style.nerd
                        font.pixelSize: 18
                    }

                    readonly property bool iconImgVisible: iconFile.source !== "" && iconImg.status !== Image.Error
                }
                Text {

                    width: parent.width - iconBox.width - parent.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("polkit.title")
                    color: Style.text1
                    font.family: Style.cjk
                    font.pixelSize: 17
                    font.bold: true
                }
            }

            Text {
                width: parent.width
                text: prompt.flow ? String(prompt.flow.message) : ""
                color: Style.text2
                font.family: Style.cjk
                font.pixelSize: 14
                wrapMode: Text.Wrap
                lineHeight: 1.25
            }

            Text {
                width: parent.width
                visible: Style.debug && text !== ""
                text: prompt.flow && prompt.flow.actionId ? String(prompt.flow.actionId) : ""
                elide: Text.ElideMiddle
                color: Style.text3
                font.family: Style.nerd
                font.pixelSize: 11
            }

            Rectangle {
                id: fieldBox
                width: parent.width
                height: 46
                radius: 10
                color: Qt.rgba(23 / 255, 33 / 255, 43 / 255, 0.80)
                border.width: prompt.errorText !== "" ? 2 : 1
                border.color: prompt.errorText !== "" ? Style.danger : (prompt.submitted ? Qt.rgba(122 / 255, 177 / 255, 234 / 255, 0.65) : Qt.rgba(1, 1, 1, 0.12))
                Behavior on border.color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                TextInput {
                    id: field
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    verticalAlignment: TextInput.AlignVCenter
                    color: Style.text1
                    font.family: Style.nerd
                    font.pixelSize: 16
                    font.letterSpacing: 4

                    echoMode: TextInput.Password
                    passwordCharacter: "\u2022"
                    selectionColor: Style.accent
                    selectedTextColor: Style.card
                    enabled: !prompt.submitted
                    focus: true
                    onAccepted: prompt.submit()
                    Keys.onEscapePressed: prompt.cancel()

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        visible: field.text === "" && !prompt.submitted
                        text: prompt.placeholder
                        color: Qt.rgba(168 / 255, 183 / 255, 198 / 255, 0.75)
                        font.family: Style.cjk
                        font.pixelSize: 15
                        font.italic: true
                    }
                }
            }

            Item {
                width: parent.width
                height: statusRow.implicitHeight

                Row {
                    id: statusRow
                    anchors.left: parent.left
                    anchors.right: capsPill.left
                    anchors.rightMargin: 8
                    spacing: 6

                    Text {

                        width: statusRow.width
                        elide: Text.ElideRight
                        anchors.verticalCenter: parent.verticalCenter

                        text: prompt.submitted ? I18n.t("polkit.verifying") : (prompt.errorText !== "" ? prompt.errorText : (prompt.infoText !== "" ? prompt.infoText : I18n.t("polkit.hint")))
                        color: prompt.submitted ? Style.text2 : (prompt.errorText !== "" ? Style.danger : (prompt.infoText !== "" ? Style.text2 : Style.text3))
                        font.family: Style.cjk
                        font.pixelSize: 12
                    }
                }

                Rectangle {
                    id: capsPill
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: prompt.capsOn
                    width: capsLabel.implicitWidth + 16
                    height: 20
                    radius: 10
                    color: Qt.rgba(122 / 255, 177 / 255, 234 / 255, 0.18)
                    border.width: 1
                    border.color: Qt.rgba(122 / 255, 177 / 255, 234 / 255, 0.55)

                    Text {
                        id: capsLabel
                        anchors.centerIn: parent
                        text: I18n.t("polkit.capsOn")
                        color: Style.accent
                        font.family: Style.cjk
                        font.pixelSize: 11
                    }
                }
            }

            Row {
                anchors.right: parent.right
                spacing: 10

                Rectangle {
                    width: cancelLabel.implicitWidth + 32
                    height: 34
                    radius: 8
                    color: cancelArea.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent"
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.14)

                    Text {
                        id: cancelLabel
                        anchors.centerIn: parent
                        text: I18n.t("polkit.cancel")
                        color: Style.text2
                        font.family: Style.cjk
                        font.pixelSize: 13
                    }
                    MouseArea {
                        id: cancelArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: prompt.cancel()
                    }
                }

                Rectangle {
                    width: okLabel.implicitWidth + 32
                    height: 34
                    radius: 8
                    color: okArea.containsMouse ? Qt.rgba(122 / 255, 177 / 255, 234 / 255, 0.30) : Qt.rgba(122 / 255, 177 / 255, 234 / 255, 0.20)
                    border.width: 1
                    border.color: Qt.rgba(122 / 255, 177 / 255, 234 / 255, 0.55)

                    Text {
                        id: okLabel
                        anchors.centerIn: parent
                        text: I18n.t("polkit.authenticate")
                        color: Style.text1
                        font.family: Style.cjk
                        font.pixelSize: 13
                    }
                    MouseArea {
                        id: okArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: prompt.submit()
                    }
                }
            }
        }
    }
}
