import QtQuick
import Quickshell
import "."

Module {
    id: pomodoro

    property int focusMin: 25
    property int breakMin: 5
    property int longMin: 15
    property int longEvery: 4

    property string phase: "idle"
    property bool running: false
    property int remaining: 0
    property int doneFocus: 0
    property real deadline: 0

    readonly property bool inBreak: phase === "break" || phase === "long"
    readonly property bool active: phase !== "idle"

    bgColor: "transparent"
    padLeft: 2
    padRight: 8
    marginRight: 2
    hoverTint: true
    contentWidth: timeText.visible ? glyphText.implicitWidth + 5 + timeText.implicitWidth : glyphText.implicitWidth

    Text {
        id: glyphText
        anchors.verticalCenter: parent.verticalCenter

        text: pomodoro.phase === "focus" ? "\u{E003}" : pomodoro.phase === "break" ? "\u{F1897}" : pomodoro.phase === "long" ? "\u{F02E3}" : "\u{E002}"
        color: pomodoro.running ? Style.accent : Style.text2
        font.family: Style.nerd
        font.pixelSize: 18
    }

    Text {
        id: timeText
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: glyphText.right
        anchors.leftMargin: 5
        visible: pomodoro.active
        text: {
            const s = Math.max(0, pomodoro.remaining);
            return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
        }
        color: Style.text1
        font.family: Style.nerd
        font.pixelSize: 13
    }

    onClicked: pomodoro.startPause()

    property var popup: null
    onRightClicked: if (popup)
        popup.open()

    function startPause() {
        if (pomodoro.running) {
            pomodoro.remaining = Math.max(0, Math.round((pomodoro.deadline - Date.now()) / 1000));
            pomodoro.running = false;
            tick.stop();
        } else if (pomodoro.active) {
            pomodoro.deadline = Date.now() + pomodoro.remaining * 1000;
            pomodoro.running = true;
            pomodoro.lastTickWall = Date.now();
            tick.restart();
        } else {
            pomodoro.beginPhase("focus");
        }
    }
    function reset() {
        pomodoro.phase = "idle";
        pomodoro.running = false;
        pomodoro.remaining = 0;
        pomodoro.doneFocus = 0;
        tick.stop();
    }
    function beginPhase(p) {
        pomodoro.phase = p;
        const min = p === "focus" ? pomodoro.focusMin : (p === "break" ? pomodoro.breakMin : pomodoro.longMin);
        pomodoro.remaining = min * 60;
        pomodoro.deadline = Date.now() + pomodoro.remaining * 1000;
        pomodoro.running = true;
        pomodoro.lastTickWall = Date.now();
        tick.restart();
    }
    function fire() {
        const sound = pomodoro.inBreak ? "/usr/share/sounds/freedesktop/stereo/complete.oga" : "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga";
        Quickshell.execDetached(["paplay", sound]);
        const key = pomodoro.inBreak ? "pomodoro.breakDone" : "pomodoro.focusDone";
        const min = pomodoro.inBreak ? (pomodoro.phase === "long" ? pomodoro.longMin : pomodoro.breakMin) : pomodoro.focusMin;
        Quickshell.execDetached(["gdbus", "call", "--session", "--dest", "org.freedesktop.Notifications", "--object-path", "/org/freedesktop/Notifications", "--method", "org.freedesktop.Notifications.Notify", "pomodoro", "0", "", I18n.t(key), I18n.fill(I18n.t(key + "Body"), {
                n: min
            }), "[]", "{}", 4000]);
        if (pomodoro.phase === "focus") {
            pomodoro.doneFocus++;
            pomodoro.beginPhase(pomodoro.doneFocus % pomodoro.longEvery === 0 ? "long" : "break");
        } else {
            pomodoro.beginPhase("focus");
        }
    }
    Component.onCompleted: if (Style.debug)
        console.log("[POMO] ready")

    property real lastTickWall: 0
    Timer {
        id: tick
        interval: 250
        repeat: true
        running: false
        onTriggered: {
            const now = Date.now();

            const gap = now - pomodoro.lastTickWall;
            if (pomodoro.lastTickWall > 0 && pomodoro.running && Math.abs(gap) > 10000)
                pomodoro.deadline += gap;
            pomodoro.lastTickWall = now;
            const left = Math.round((pomodoro.deadline - now) / 1000);
            pomodoro.remaining = Math.max(0, left);
            if (left <= 0) {
                tick.stop();
                pomodoro.running = false;
                pomodoro.fire();
            }
        }
    }
}
