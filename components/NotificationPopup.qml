import QtQuick
import Quickshell.Services.Notifications
import Quickshell.Widgets

Item {
    id: card

    property var notification: null

    property var center: null

    property bool noteClosed: false

    property int cardWidth: 300
    property int defaultTimeout: 5000
    property int maxBodyLines: card.detailNotice ? 6 : 3

    readonly property var note: card.notification
    readonly property int urgency: card.note ? card.note.urgency : NotificationUrgency.Normal

    readonly property bool detailNotice: !!card.note && !!card.note.hints && String(card.note.hints["x-quickshell-reboot"] || "") !== ""

    readonly property int timeoutMs: {
        if (!card.note)
            return 0;
        const t = card.note.expireTimeout;
        if (t === 0)
            return 0;
        if (t > 0)
            return Math.round(t);
        return card.defaultTimeout;
    }

    readonly property int pad: 12
    readonly property int iconSize: 28
    readonly property int iconGap: 10

    readonly property bool hasIcon: !!card.note && ((card.note.appIcon && card.note.appIcon !== "") || (card.note.image && card.note.image !== "") || (card.note.desktopEntry && card.note.desktopEntry !== ""))
    readonly property real textX: card.pad + (card.hasIcon ? card.iconSize + card.iconGap : 0)
    readonly property real textWidth: card.cardWidth - card.textX - card.pad
    readonly property real contentHeight: Math.max(card.hasIcon ? card.iconSize : 0, textCol.implicitHeight)

    implicitWidth: card.cardWidth
    implicitHeight: card.pad * 2 + card.contentHeight

    SafeMouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            const n = card.note;
            if (!n)
                return;
            for (const a of Style.modelValues(n.actions)) {
                if (a.identifier === "default") {
                    a.invoke();
                    return;
                }
            }
            if (!card.noteClosed)
                n.dismiss();
        }
    }

    Rectangle {
        id: bg
        width: card.cardWidth
        height: card.implicitHeight
        radius: 12
        color: Style.notifBg(card.urgency)
        border.width: 2
        border.color: Style.notifBorder(card.urgency)

        FileIcon {
            id: iconFile
            visible: false
            iconNames: {
                if (!card.note)
                    return [];
                const names = [];
                if (card.note.image)
                    names.push(card.note.image);
                if (card.note.appIcon)
                    names.push(card.note.appIcon);
                if (card.note.desktopEntry)
                    names.push(card.note.desktopEntry);
                return names;
            }
        }

        IconImage {
            id: iconImg
            x: card.pad
            y: card.pad + (card.contentHeight - card.iconSize) / 2
            width: card.iconSize
            height: card.iconSize
            visible: card.hasIcon && source !== "" && status !== Image.Error
            source: iconFile.source
        }

        Text {
            anchors.centerIn: iconImg
            visible: card.hasIcon && (!iconImg.visible)
            text: "●"
            color: Style.text3
            font.family: Style.cjk
            font.pixelSize: 10
        }

        Column {
            id: textCol
            x: card.textX
            y: card.pad
            width: card.textWidth
            spacing: 4

            Text {
                width: textCol.width
                text: card.note ? card.note.summary : ""
                visible: text !== ""
                color: Style.notifText
                font.family: Style.cjk
                font.pixelSize: 16
                font.bold: true
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Text {
                width: textCol.width
                text: card.note ? card.note.body : ""
                visible: text !== ""
                color: Style.notifText
                font.family: Style.cjk
                font.pixelSize: 14
                wrapMode: Text.Wrap
                maximumLineCount: card.maxBodyLines
                elide: Text.ElideRight
            }

            Flow {
                width: textCol.width
                spacing: 6
                visible: actionRepeater.count > 0

                Repeater {
                    id: actionRepeater
                    model: card.note ? card.note.actions : []

                    delegate: Rectangle {
                        id: pill
                        required property var modelData
                        readonly property string label: pill.modelData ? String(pill.modelData.text || "") : ""

                        visible: label !== ""
                        implicitWidth: pillText.implicitWidth + 24
                        implicitHeight: 26
                        radius: 13
                        color: pillMouse.containsMouse ? Style.notifBorder(card.urgency) : Style.withAlpha(Style.text1, 0.10)

                        Text {
                            id: pillText
                            anchors.centerIn: parent
                            text: pill.label

                            color: pillMouse.containsMouse ? Style.card : Style.notifText
                            font.family: Style.cjk
                            font.pixelSize: 13
                        }

                        SafeMouseArea {
                            id: pillMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const a = pill.modelData;
                                if (!a)
                                    return;
                                a.invoke();
                            }
                        }
                    }
                }
            }
        }
    }

    property double expireAt: 0
    property int pausedRemaining: 0

    function armExpiry() {
        if (card.note === null || card.timeoutMs <= 0)
            return;
        card.expireAt = Date.now() + card.timeoutMs;
        card.pausedRemaining = card.timeoutMs;
        card.rearmExpiry();
    }

    onNoteChanged: {
        card.noteClosed = false;
        card.armExpiry();
    }

    function rearmExpiry() {
        if (!card.note)
            return;
        if (!expireTimer)
            return;
        expireTimer.stop();
        if (card.timeoutMs <= 0)
            return;
        if (card.center && card.center.popupSuppressed)
            return;
        expireTimer.interval = Math.max(1, Math.round(card.expireAt - Date.now()));
        expireTimer.start();
    }

    Connections {
        target: card.center
        function onPopupSuppressedChanged() {
            if (!card.center)
                return;
            if (card.center.popupSuppressed) {
                card.pausedRemaining = Math.max(0, card.expireAt - Date.now());
                if (expireTimer)
                    expireTimer.stop();
            } else if (card.note !== null && card.timeoutMs > 0) {
                card.expireAt = Date.now() + card.pausedRemaining;
                card.rearmExpiry();
            }
        }
    }

    Timer {
        id: expireTimer
        repeat: false

        onTriggered: {
            if (card.note === null || card.expireAt <= 0)
                return;

            if (card.noteClosed)
                return;
            if (Date.now() >= card.expireAt)
                card.note.expire();
            else
                card.rearmExpiry();
        }
    }

    Connections {
        target: card.note
        function onClosed(reason) {
            card.noteClosed = true;
            if (expireTimer)
                expireTimer.stop();
            if (card.center && card.note)
                card.center.markClosed(card.note.id);
        }
    }

    opacity: 0
    Behavior on opacity {
        NumberAnimation {
            duration: 120
        }
    }
    Component.onCompleted: {
        card.opacity = 1;
        card.armExpiry();
    }
}
