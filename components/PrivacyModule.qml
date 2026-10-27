import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Module {
    id: privacyModule

    required property var qsRoot
    required property var panel

    shown: qsRoot.showPrivacy && (privacyModule.micActive || privacyModule.shareActive)
    bgColor: "transparent"

    hoverTint: privacyModule.micActive
    radius: 0

    padLeft: 3
    padRight: 3
    marginRight: 0
    contentYOffset: 1
    contentWidth: privacyRow.implicitWidth

    property bool micActive: false
    property bool shareActive: false

    property var activeMicSources: []
    readonly property var source: {
        const fallback = Pipewire.defaultAudioSource;
        const used = privacyModule.activeMicSources;
        if (fallback) {
            const fid = String(fallback.id);
            for (const n of used)
                if (n && String(n.id) === fid)
                    return fallback;
        }
        return used.length > 0 ? used[0] : fallback;
    }
    readonly property var sourceAudio: (privacyModule.source && privacyModule.source.audio) ? privacyModule.source.audio : null
    readonly property bool micMuted: privacyModule.sourceAudio ? privacyModule.sourceAudio.muted === true : false
    PwObjectTracker {
        objects: privacyModule.source ? [privacyModule.source] : []
    }

    function toggleMicMute() {
        const a = privacyModule.sourceAudio;
        if (!a) {
            console.log("[PRIVACY] no controllable mic source, mute skipped");
            return;
        }
        a.muted = !a.muted;
        console.log("[PRIVACY] mic mute → " + (a.muted ? "on" : "off"));
    }
    function applyMicVol(p, how) {
        p = Math.round(Math.min(100, Math.max(0, p)));
        const a = privacyModule.sourceAudio;
        if (!a)
            return;
        a.volume = p / 100;
        if (p > 0 && a.muted)
            a.muted = false;
        console.log("[PRIVACY] mic volume " + (how || "set") + " → " + p + "%");
    }
    onClicked: if (privacyModule.micActive)
        micPopup.open()
    onRightClicked: if (privacyModule.micActive)
        privacyModule.toggleMicMute()
    onShownChanged: if (!privacyModule.shown)
        micPopup.close()
    onMicActiveChanged: if (!privacyModule.micActive)
        micPopup.close()
    onSourceAudioChanged: if (!privacyModule.sourceAudio)
        micPopup.close()

    function isMicStream(n) {
        if (!n)
            return false;
        const t = Number(n.type);
        return (t & 4) !== 0 && (t & 1) !== 0 && (t & 8) !== 0;
    }

    function isUserMicStream(n) {
        if (!privacyModule.isMicStream(n))
            return false;
        const p = n.properties || {};
        const monitor = p["stream.monitor"];
        if (monitor === true || String(monitor || "").toLowerCase() === "true")
            return false;
        return String(p["media.class"] || "").indexOf("/Internal") < 0;
    }

    function refreshMicSources() {
        const found = [];
        const add = n => {
            if (!n || !n.audio)
                return;
            for (const old of found)
                if (String(old.id) === String(n.id))
                    return;
            found.push(n);
        };
        for (const link of Style.modelValues(Pipewire.links)) {
            if (!link || link.state !== PwLinkState.Active)
                continue;
            if (privacyModule.isUserMicStream(link.target))
                add(link.source);
            if (privacyModule.isUserMicStream(link.source))
                add(link.target);
        }
        const old = privacyModule.activeMicSources;
        const same = found.length === old.length && found.every((n, i) => String(n.id) === String(old[i].id));

        if (!same)
            privacyModule.activeMicSources = found;
    }
    function refreshPrivacy() {
        let mic = false, share = false;
        const nodes = Style.modelValues(Pipewire.nodes);
        for (const n of nodes) {
            if (!n)
                continue;

            const t = Number(n.type);
            if (privacyModule.isUserMicStream(n))
                mic = true;
            if ((t & 4) && (t & 2))
                share = true;
        }
        privacyModule.micActive = mic;
        privacyModule.shareActive = share;
        privacyModule.refreshMicSources();
        if (Style.debug) {
            console.log("[PRIVACY] nodes=" + nodes.length + " mic=" + mic + " share=" + share + " comp=" + Style.compositor + " sources=" + privacyModule.activeMicSources.length + " title=" + JSON.stringify(Compositor.activeTitle));
        }
    }

    Connections {
        target: Pipewire.nodes

        enabled: qsRoot.showPrivacy
        function onValuesChanged() {
            privacyModule.refreshPrivacy();
        }
    }
    Connections {
        target: Pipewire.links
        enabled: qsRoot.showPrivacy
        function onValuesChanged() {
            privacyModule.refreshMicSources();
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: qsRoot.showPrivacy
        triggeredOnStart: true
        onTriggered: privacyModule.refreshPrivacy()
    }

    Row {
        id: privacyRow

        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        spacing: 4

        Text {
            visible: privacyModule.micActive

            text: privacyModule.micMuted ? "\uF131" : "\uF130"
            color: privacyModule.micMuted ? Style.text3 : Style.privacyRed
            font.family: Style.nerd
            font.pixelSize: 18
        }
        Text {
            visible: privacyModule.shareActive
            text: "\uF108"
            color: Style.privacyOrange
            font.family: Style.nerd
            font.pixelSize: 18
        }
    }

    PopupWindow {
        id: micPopup
        visible: false
        function open() {
            if (!privacyModule.sourceAudio)
                return;
            micPopup.visible = true;
        }
        function close() {
            micPopup.visible = false;
        }

        color: "transparent"
        implicitWidth: 224
        implicitHeight: 48 + Style.barHeight + 2 - Style.barInset
        grabFocus: true
        anchor.window: privacyModule.panel
        anchor.item: privacyModule
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Top

        Rectangle {
            id: micCard
            anchors.fill: parent

            anchors.topMargin: Style.barHeight + 2 - Style.barInset
            radius: 12
            color: Style.card
            border.width: 1
            border.color: Style.border
            focus: true
            Keys.onEscapePressed: micPopup.close()

            property bool dragging: false
            property int dragPct: 0
            property int lastX: -1
            property real wheelAccum: 0

            function setFromX(px) {
                lastX = Math.round(px);
                dragPct = Math.round(Math.min(100, Math.max(0, px - micTrough.x) / Math.max(1, micTrough.width) * 100));
            }

            readonly property int shownPct: micCard.dragging ? micCard.dragPct : (privacyModule.micMuted ? 0 : Math.round((privacyModule.sourceAudio ? Number(privacyModule.sourceAudio.volume) || 0 : 0) * 100))

            Rectangle {
                id: micTrough
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 150
                height: 5
                radius: 5
                color: Style.trough

                Rectangle {
                    width: parent.width * Math.min(1, Math.max(0, micCard.shownPct / 100))
                    height: parent.height
                    radius: 5
                    color: Style.fill

                    Behavior on width {
                        enabled: !micCard.dragging
                        NumberAnimation {
                            duration: 150
                        }
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                x: micTrough.x + micTrough.width + 10
                text: (privacyModule.micMuted && !micCard.dragging) ? I18n.t("mic.muted") : micCard.shownPct + "%"
                color: (privacyModule.micMuted && !micCard.dragging) ? Style.text3 : Style.text2
                font.family: Style.cjk
                font.pixelSize: 14
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton

                onWheel: ev => {
                    if (ev.angleDelta.y === 0)
                        return;
                    micCard.wheelAccum += ev.angleDelta.y;
                    while (Math.abs(micCard.wheelAccum) >= 120) {
                        const dir = micCard.wheelAccum > 0 ? 1 : -1;
                        micCard.wheelAccum -= dir * 120;
                        privacyModule.applyMicVol(micCard.shownPct + dir * 5, "wheel");
                    }
                }
                onPressed: m => {
                    micCard.dragging = true;
                    micCard.setFromX(m.x);
                }
                onReleased: m => {
                    micCard.dragging = false;

                    privacyModule.applyMicVol(micCard.dragPct, "x" + micCard.lastX);
                }
                onCanceled: micCard.dragging = false
                onPositionChanged: m => {
                    if (micCard.dragging)
                        micCard.setFromX(m.x);
                }
            }
        }
    }
}
