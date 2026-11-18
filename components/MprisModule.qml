import QtQuick
import Quickshell.Services.Mpris

Module {
    id: mprisModule

    required property var qsRoot

    shown: qsRoot.showMpris && mprisModule.player !== null
    bgColor: "transparent"
    radius: 5
    padLeft: 7
    padRight: 2
    marginRight: 2

    contentYOffset: -1

    contentWidth: mprisRail.width

    readonly property var player: {
        const ps = Style.modelValues(Mpris.players);
        for (const p of ps)
            if (p.playbackState === MprisPlaybackState.Playing)
                return p;

        for (const p of ps)
            if (p.canTogglePlaying === true || p.canPlay === true)
                return p;
        return ps.length ? ps[0] : null;
    }

    readonly property bool playing: mprisModule.player !== null && mprisModule.player.playbackState === MprisPlaybackState.Playing

    readonly property int iconGap: 4

    Item {
        id: mprisRail

        x: (parent.width - width) / 2
        y: (parent.height - mprisModule.progressReserve - height) / 2
        width: mprisIconText.implicitWidth + mprisModule.iconGap + mprisViewport.width
        height: mprisIconText.implicitHeight

        opacity: mprisModule.playing ? 1.0 : 0.65
        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }

        Text {
            id: mprisIconText
            x: 0
            y: 0
            color: Style.text1
            font.family: Style.cjk
            font.pixelSize: 18
            text: mprisModule.playing ? "\uf04b" : "\uf04c"
        }

        Item {
            id: mprisViewport
            x: mprisIconText.implicitWidth + mprisModule.iconGap

            y: mprisIconText.baselineOffset - mprisText.baselineOffset
            width: Math.min(mprisText.implicitWidth, 260)
            height: mprisText.implicitHeight
            clip: true

            readonly property real overflow: Math.max(0, mprisText.implicitWidth - width)

            Text {
                id: mprisText

                textFormat: Text.RichText
                color: Style.text1
                font.family: Style.cjk

                font.pixelSize: 14
                text: {
                    const p = mprisModule.player;
                    if (!p)
                        return "";
                    const esc = s => String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
                    const artist = String(p.trackArtists || "");
                    const album = String(p.trackAlbum || "");

                    const dim = '<font color="' + Style.text3 + '">';
                    const close = "</font>";
                    const sep = dim + " - " + close;
                    const title = esc(p.trackTitle);
                    let segs = [];
                    if (title)
                        segs.push(title);
                    if (artist)
                        segs.push(dim + esc(artist) + close);
                    if (album)
                        segs.push(dim + esc(album) + close);
                    return segs.join(sep);
                }

                onTextChanged: Qt.callLater(function () {
                    if (mprisModule && mprisViewport && mprisModule.visible && mprisViewport.overflow > 0)
                        marquee.restart();
                })
            }

            SequentialAnimation {
                id: marquee
                running: mprisModule.visible && mprisViewport.overflow > 0
                loops: Animation.Infinite

                onRunningChanged: if (!marquee.running)
                    mprisText.x = 0
                PauseAnimation {
                    duration: 1600
                }
                NumberAnimation {
                    target: mprisText
                    property: "x"
                    to: -mprisViewport.overflow
                    duration: Math.max(1800, mprisViewport.overflow * 22)
                    easing.type: Easing.InOutSine
                }
                PauseAnimation {
                    duration: 1600
                }
                NumberAnimation {
                    target: mprisText
                    property: "x"
                    to: 0
                    duration: Math.max(1800, mprisViewport.overflow * 22)
                    easing.type: Easing.InOutSine
                }
            }
        }
    }

    property real playedSec: 0
    property real lastReportedPos: -1
    readonly property real totalSec: mprisModule.player ? Math.max(0, Number(mprisModule.player.length) || 0) : 0

    readonly property real progressFrac: mprisModule.totalSec > 0 ? Math.max(0, Math.min(1, mprisModule.playedSec / mprisModule.totalSec)) : -1

    readonly property int progressReserve: mprisModule.progressFrac >= 0 ? 2 : 0

    Timer {
        interval: 1000
        repeat: true
        running: mprisModule.visible && mprisModule.totalSec > 0
        onTriggered: {
            const p = mprisModule.player;
            if (!p)
                return;
            const reported = Math.max(0, Number(p.position) || 0);
            if (Math.abs(reported - mprisModule.lastReportedPos) > 0.05)
                mprisModule.playedSec = reported;
            else if (mprisModule.playing)
                mprisModule.playedSec = Math.min(mprisModule.totalSec, mprisModule.playedSec + 1);
            mprisModule.lastReportedPos = reported;
        }
    }

    Rectangle {
        visible: mprisModule.progressFrac >= 0
        x: mprisIconText.implicitWidth + mprisModule.iconGap
        y: mprisModule.implicitHeight - 2 - mprisModule.contentYOffset
        width: mprisViewport.width
        height: 2
        radius: 1
        color: Style.trough
    }

    Rectangle {
        visible: mprisModule.progressFrac >= 0
        x: mprisIconText.implicitWidth + mprisModule.iconGap
        y: mprisModule.implicitHeight - 2 - mprisModule.contentYOffset
        width: mprisViewport.width * Math.max(0, mprisModule.progressFrac)
        height: 2
        radius: 1
        color: Style.accent
        opacity: mprisModule.playing ? 0.85 : 0.45
        Behavior on width {
            NumberAnimation {
                duration: 950
                easing.type: Easing.Linear
            }
        }
    }

    onClicked: {
        const p = mprisModule.player;
        if (!p)
            return;
        if (typeof p.togglePlaying === "function" && p.canTogglePlaying !== false) {
            p.togglePlaying();
        } else if (p.playbackState === MprisPlaybackState.Playing && p.canPause) {
            p.pause();
        } else if (p.canPlay) {
            p.play();
        }
    }

    onRightClicked: {
        const p = mprisModule.player;
        if (!p)
            return;
        if (typeof p.next === "function" && p.canGoNext !== false)
            p.next();
    }

    wheelEnabled: true
    onWheelNotch: d => {
        const p = mprisModule.player;
        if (!p)
            return;
        if (d > 0) {
            if (typeof p.next === "function" && p.canGoNext !== false)
                p.next();
        } else {
            if (typeof p.previous === "function" && p.canGoPrevious !== false)
                p.previous();
        }
    }

    property bool testToggled: false
    onPlayerChanged: {
        const p = mprisModule.player;
        mprisModule.playedSec = p ? Math.max(0, Number(p.position) || 0) : 0;
        mprisModule.lastReportedPos = p ? Math.max(0, Number(p.position) || 0) : -1;
        if (Style.debug)
            console.log("[MPRISW] player:", player ? String(player.identity) : "null", "| textIW:", mprisText.implicitWidth, "| vpW:", mprisViewport.width);
        if (!Style.debug || !mprisModule.player || mprisModule.testToggled)
            return;
        mprisModule.testToggled = true;
        mprisTestTimer.restart();
    }
    Timer {
        id: mprisTestTimer
        interval: 2000
        onTriggered: {
            if (!Style.debug || !mprisModule.player)
                return;
            const p = mprisModule.player;
            console.log("[MPRIS-TEST] player:", String(p.identity), "| togglePlaying:", typeof p.togglePlaying, "| canTogglePlaying:", String(p.canTogglePlaying), "| canPause:", String(p.canPause), "| canPlay:", String(p.canPlay), "| state:", String(p.playbackState));
            mprisModule.clicked();
        }
    }
}
