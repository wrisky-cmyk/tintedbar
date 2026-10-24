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

    contentWidth: mprisViewport.width

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

    Item {
        id: mprisViewport

        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
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

                const icon = '<span style="font-size:18px">' + (p.playbackState !== MprisPlaybackState.Playing ? "\uf04c" : "\uf04b") + '</span>';

                const dim = '<font color="' + Style.text3 + '">';
                const close = "</font>";
                const title = esc(p.trackTitle);
                let segs = [];
                if (artist)
                    segs.push(dim + esc(artist) + close);
                if (album)
                    segs.push(dim + esc(album) + close);
                if (title)
                    segs.push(title);
                return icon + " " + segs.join(" - ");
            }

            onTextChanged: Qt.callLater(function () {
                if (mprisModule.visible && mprisViewport.overflow > 0)
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
