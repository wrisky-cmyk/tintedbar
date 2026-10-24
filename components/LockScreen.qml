import QtQuick
import Quickshell
import Quickshell.Services.Pam
import Quickshell.Wayland
import "."

Item {
    id: lockScreen

    property string userName: Quickshell.env("USER") || ""

    property string pamConfig: "quickshell-lock"

    property string wallpaper: ""

    property bool hideInput: true

    property bool locked: false

    property int idleLockMinutes: 5

    property int idleDpmsMinutes: 10

    property bool dpmsOffByUs: false

    property bool capsOn: false

    readonly property string userInitial: lockScreen.userName.length > 0 ? lockScreen.userName[0].toUpperCase() : "?"

    signal unlocked
    signal authFailed

    readonly property int unlockFadeMs: 160
    readonly property alias secure: lock.secure

    property int attempts: 0
    property bool pamReady: false
    property bool busy: false
    property bool unlocking: false
    property string failText: ""

    property double lockoutUntil: 0

    property string activePamConfig: lockScreen.pamConfig

    property bool surfaceSeen: false

    property int secureMisses: 0

    readonly property string timeStr: {
        const d = clock.date;
        return (d && !isNaN(d.getTime())) ? Qt.formatDateTime(d, "HH:mm") : "";
    }

    readonly property string dateStr: {
        const d = clock.date;
        if (!(d && !isNaN(d.getTime())))
            return "";
        const p = I18n.dateParts(false);
        return p.wd + " · " + p.day;
    }

    function lockNow() {
        if (lockScreen.locked)
            return;
        lockScreen.attempts = 0;
        lockScreen.lockoutUntil = 0;
        lockoutTimer.stop();
        lockScreen.failText = "";
        lockScreen.busy = false;
        lockScreen.unlocking = false;
        lockScreen.secureMisses = 0;
        lockScreen.activePamConfig = lockScreen.pamConfig;
        lockScreen.locked = true;
        lockScreen.startPam();

        secureCheck.restart();
    }

    function unlockNow() {
        if (!lockScreen.locked)
            return;
        lockScreen.locked = false;
        lockScreen.lockoutUntil = 0;
        lockoutTimer.stop();
        lockScreen.pamReady = false;
        lockScreen.busy = false;
        pamStartWatchdog.stop();
        if (pam.active)
            pam.abort();
        lockScreen.unlocked();
    }

    function startPam(watchdogInterval) {
        lockScreen.pamReady = false;
        if (pam.active)
            pam.abort();

        if (pam.user !== lockScreen.userName)
            pam.user = lockScreen.userName;
        if (pam.config !== lockScreen.activePamConfig)
            pam.config = lockScreen.activePamConfig;
        pam.active = true;
        pamStartWatchdog.interval = watchdogInterval > 0 ? watchdogInterval : 2000;
        pamStartWatchdog.restart();
    }

    function startLockout() {
        if (lockScreen.attempts < 3)
            return;
        const secs = Math.min(Math.pow(2, lockScreen.attempts - 3), 16);
        lockScreen.lockoutUntil = Date.now() + secs * 1000;
        lockoutTimer.restart();
    }

    function submit(password) {
        if (password === "" || lockScreen.busy || !pam.responseRequired)
            return;
        if (Date.now() < lockScreen.lockoutUntil)
            return;
        lockScreen.busy = true;
        lockScreen.pamReady = false;
        lockScreen.failText = "";
        pam.respond(password);
    }

    function finishUnlock() {
        if (lockScreen.unlocking)
            return;
        lockScreen.unlocking = true;
        unlockTimer.restart();
    }

    function screenOff() {
        if (lockScreen.dpmsOffByUs)
            return;
        lockScreen.dpmsOffByUs = true;
        console.log("[DPMS] idle " + lockScreen.idleDpmsMinutes + " min, dpms off(" + Style.compositor + ", locked=" + lockScreen.locked + ")");
        Compositor.setDpms(false);
    }

    function screenOn() {
        console.log("[DPMS] activity, dpms on(" + Style.compositor + ", prev=" + (lockScreen.dpmsOffByUs ? "off by us" : "not by us") + ")");
        lockScreen.dpmsOffByUs = false;
        Compositor.setDpms(true);
    }

    component IdleWatcher: Loader {
        id: watcher
        required property int minutes
        property var onIdle: null
        property var onResume: null
        active: false
        sourceComponent: Component {
            IdleMonitor {
                timeout: Math.max(1, watcher.minutes) * 60
                respectInhibitors: true
                onIsIdleChanged: {
                    if (isIdle) {
                        if (watcher.onIdle)
                            watcher.onIdle();
                    } else if (watcher.onResume)
                        watcher.onResume();
                }
            }
        }
        function rearm() {
            active = false;
            if (watcher.minutes > 0)
                active = true;
        }
        onMinutesChanged: rearm()
        Component.onCompleted: rearm()
    }

    IdleWatcher {
        minutes: lockScreen.locked ? 0 : lockScreen.idleLockMinutes
        onIdle: () => {
            console.log("[LOCK] idle " + lockScreen.idleLockMinutes + " min, auto lock");
            lockScreen.lockNow();
        }
    }

    IdleWatcher {
        minutes: lockScreen.idleDpmsMinutes
        onIdle: () => lockScreen.screenOff()
        onResume: () => lockScreen.screenOn()
    }

    Poller {
        active: lockScreen.locked
        interval: 3000
        command: ["sh", "-c", "v=; for f in /sys/class/leds/*::capslock/brightness; do " + "[ -e \"$f\" ] || break; read -r v < \"$f\"; break; done; " + "if [ -n \"$v\" ]; then printf 'led %s\\n' \"$v\"; " + (Style.compositor === "niri" ? "else printf 'led 0\\n'; fi" : "else exec hyprctl devices -j; fi")]
        onOutput: text => {
            const t = String(text).trim();

            if (t.indexOf("led ") === 0) {
                lockScreen.capsOn = t.split(/\s+/)[1] === "1";
                return;
            }

            try {
                const d = JSON.parse(t);
                let caps = false;
                for (const k of (d.keyboards || []))
                    if (k.capsLock === true)
                        caps = true;
                lockScreen.capsOn = caps;
            } catch (e) {}
        }
    }

    WlSessionLock {
        id: lock
        locked: lockScreen.locked
        surface: lockScreen.surfaceComponent
    }

    SystemClock {
        id: clock
        enabled: lockScreen.locked
        precision: SystemClock.Minutes
    }

    Timer {
        id: unlockTimer
        interval: lockScreen.unlockFadeMs
        onTriggered: lockScreen.unlockNow()
    }

    Timer {
        id: lockoutTimer
        interval: 1000
        repeat: true
        running: false
        onTriggered: {
            const left = Math.ceil((lockScreen.lockoutUntil - Date.now()) / 1000);
            if (left > 0) {
                lockScreen.failText = I18n.fill(I18n.t("lock.retry"), {
                    n: left
                });
                return;
            }
            stop();
            lockScreen.failText = I18n.t("lock.failed");
        }
    }

    Timer {
        id: pamStartWatchdog
        interval: 2000
        onTriggered: {
            if (lockScreen.pamReady || lockScreen.busy)
                return;
            if (lockScreen.activePamConfig !== "login") {
                console.log("[LOCK] pam(" + lockScreen.activePamConfig + ") not in waiting-for-input state, fall back to login");
                lockScreen.activePamConfig = "login";
                lockScreen.startPam();
                return;
            }
            lockScreen.failText = I18n.t("lock.pamUnavailable");

            lockScreen.startPam(10000);
        }
    }

    Timer {
        id: secureCheck
        interval: 5000
        onTriggered: {
            if (!lockScreen.locked || lock.secure)
                return;
            if (lockScreen.surfaceSeen) {
                console.log("[LOCK] secure=false but lock surface exists, staying locked");
                return;
            }
            if (++lockScreen.secureMisses < 3) {
                restart();
                return;
            }
            console.log("[LOCK] compositor lacks ext-session-lock (no lock surface in 15s), abandoning this lock");
            lockScreen.unlockNow();
        }
    }

    PamContext {
        id: pam
        user: lockScreen.userName
        config: lockScreen.activePamConfig

        onPamMessage: {
            if (pam.responseRequired)
                lockScreen.pamReady = true;

            if (pam.messageIsError && pam.message !== "")
                lockScreen.failText = pam.message;
        }

        onCompleted: result => {
            lockScreen.busy = false;
            lockScreen.pamReady = false;
            if (result === PamResult.Success) {
                lockScreen.finishUnlock();
                return;
            }

            lockScreen.attempts++;

            lockScreen.failText = pam.message !== "" ? pam.message : I18n.t("lock.failed");
            lockScreen.authFailed();
            lockScreen.startLockout();
            lockScreen.startPam();
        }

        onError: error => {
            lockScreen.busy = false;
            lockScreen.pamReady = false;

            if (error === PamError.StartFailed && lockScreen.activePamConfig !== "login") {
                console.log("[LOCK] pam config " + lockScreen.activePamConfig + " unavailable, fall back to login");
                lockScreen.activePamConfig = "login";
                lockScreen.startPam();
                return;
            }
            lockScreen.failText = PamError.toString(error);
            lockScreen.authFailed();

            if (error === PamError.StartFailed)
                return;
            lockScreen.startPam();
        }
    }

    property Component surfaceComponent: Component {
        WlSessionLockSurface {
            id: surf

            color: WallpaperMap.colorFor(surf.screen ? surf.screen.name : "") || Style.bgSolid

            onVisibleChanged: if (surf.visible)
                lockScreen.surfaceSeen = true
            onWidthChanged: if (surf.width > 0)
                lockScreen.surfaceSeen = true

            Image {
                id: wallpaperImage
                anchors.fill: parent

                source: {
                    const p = lockScreen.wallpaper !== "" ? lockScreen.wallpaper : WallpaperMap.pathFor(surf.screen ? surf.screen.name : "");

                    return WallpaperMap.fileUrl(p);
                }

                sourceSize.width: {
                    const s = surf.screen;
                    if (s && s.width > 0)
                        return Math.round(s.width * (s.devicePixelRatio || 1));
                    return surf.width > 0 ? surf.width : 1920;
                }
                fillMode: Image.PreserveAspectCrop
                asynchronous: false
                cache: false
                visible: status === Image.Ready
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: Qt.rgba(14 / 255, 22 / 255, 33 / 255, 0.46)
                    }
                    GradientStop {
                        position: 1.0
                        color: Qt.rgba(14 / 255, 22 / 255, 33 / 255, 0.78)
                    }
                }
            }

            Item {
                id: content

                readonly property real k: {
                    if (surf.width <= 0 || surf.height <= 0)
                        return 1;
                    return Math.min(surf.width / 1600, surf.height / 900);
                }
                width: 1600
                height: 900
                anchors.centerIn: parent
                scale: k
                opacity: lockScreen.unlocking ? 0 : 1
                Behavior on opacity {
                    NumberAnimation {
                        duration: lockScreen.unlockFadeMs
                    }
                }

                Rectangle {
                    id: capsChip
                    visible: lockScreen.capsOn
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 28
                    width: capsChipLabel.implicitWidth + 22
                    height: 28
                    radius: 14
                    color: Qt.rgba(215 / 255, 90 / 255, 90 / 255, 0.22)
                    border.width: 1
                    border.color: Qt.rgba(215 / 255, 90 / 255, 90 / 255, 0.55)

                    Text {
                        id: capsChipLabel
                        anchors.centerIn: parent
                        text: I18n.t("lock.capsOn")

                        color: "#f0b3b3"
                        font.family: Style.cjk
                        font.pixelSize: 13
                    }
                }

                Column {
                    id: leftStack
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 96
                    anchors.bottomMargin: 96
                    spacing: 0

                    Text {
                        id: timeLabel
                        text: lockScreen.timeStr
                        color: Style.lockText
                        font.family: Style.nerd
                        font.pixelSize: 132
                        font.weight: Font.Medium
                        font.letterSpacing: -2

                        style: Text.Raised
                        styleColor: Qt.rgba(0, 0, 0, 0.45)
                    }
                    Item {
                        width: 1
                        height: 2
                    }
                    Text {
                        id: dateLabel
                        text: lockScreen.dateStr
                        color: Style.lockText2
                        font.family: Style.cjk
                        font.pixelSize: 22
                    }
                    Item {
                        width: 1
                        height: 46
                    }

                    Rectangle {
                        id: fieldBox
                        width: 360
                        height: 56
                        radius: height / 2
                        color: lockScreen.failText !== "" ? Qt.rgba(215 / 255, 90 / 255, 90 / 255, 0.16) : Qt.rgba(23 / 255, 33 / 255, 43 / 255, 0.80)
                        border.width: lockScreen.failText !== "" ? 2 : 1
                        border.color: lockScreen.failText !== "" ? Style.danger : (lockScreen.busy ? Qt.rgba(122 / 255, 177 / 255, 234 / 255, 0.65) : Qt.rgba(1, 1, 1, 0.12))
                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }
                        Behavior on border.color {
                            ColorAnimation {
                                duration: 120
                            }
                        }

                        TextInput {
                            id: field
                            anchors.fill: parent
                            anchors.leftMargin: 26
                            anchors.rightMargin: 20
                            verticalAlignment: TextInput.AlignVCenter
                            color: Style.lockText
                            font.family: Style.nerd
                            font.pixelSize: 17

                            font.letterSpacing: lockScreen.hideInput ? 4 : 0
                            echoMode: lockScreen.hideInput ? TextInput.Password : TextInput.Normal
                            passwordCharacter: "\u2022"
                            selectionColor: Style.accent
                            selectedTextColor: Style.card

                            enabled: !lockScreen.busy
                            focus: true
                            onAccepted: lockScreen.submit(text)
                            Keys.onEscapePressed: field.text = ""
                            Component.onCompleted: field.forceActiveFocus()

                            Connections {
                                target: lockScreen
                                function onAuthFailed() {
                                    field.text = "";
                                }
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                visible: field.text === "" && !lockScreen.busy
                                text: I18n.t("lock.placeholder")
                                color: Qt.rgba(168 / 255, 183 / 255, 198 / 255, 0.75)
                                font.family: Style.cjk
                                font.pixelSize: 16
                                font.italic: true
                            }
                        }
                    }
                    Item {
                        width: 1
                        height: 14
                    }

                    Text {
                        id: statusLabel
                        text: {
                            if (lockScreen.failText === "")
                                return I18n.t("lock.hint");
                            const n = I18n.fill(I18n.t("lock.attempts"), {
                                n: lockScreen.attempts
                            });
                            return lockScreen.attempts > 0 ? lockScreen.failText + "  " + n : lockScreen.failText;
                        }

                        color: lockScreen.failText !== "" ? "#e08585" : Qt.rgba(168 / 255, 183 / 255, 198 / 255, 0.65)
                        font.family: Style.cjk
                        font.pixelSize: lockScreen.failText !== "" ? 15 : 13
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: 96
                    anchors.bottomMargin: 104
                    spacing: 12

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: lockScreen.userName
                        color: Qt.rgba(211 / 255, 220 / 255, 229 / 255, 0.85)
                        font.family: Style.cjk
                        font.pixelSize: 17
                    }

                    Rectangle {
                        width: 34
                        height: 34
                        radius: width / 2
                        color: Qt.rgba(23 / 255, 33 / 255, 43 / 255, 0.86)
                        border.width: 1.5
                        border.color: Qt.rgba(122 / 255, 177 / 255, 234 / 255, 0.55)

                        Text {
                            anchors.centerIn: parent
                            text: lockScreen.userInitial
                            color: Style.accent
                            font.family: Style.cjk
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }
        }
    }
}
