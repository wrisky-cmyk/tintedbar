import QtQuick
import Quickshell.Io

Module {
    id: brightnessModule

    required property var qsRoot
    required property var brightnessPopup

    bgColor: "transparent"
    radius: 5
    marginLeft: 6
    padLeft: 1
    padRight: 1
    contentYOffset: 1
    contentWidth: brightIcon.implicitWidth

    property string backend: ""
    property int pct: -1

    property string sysfsDev: ""
    property int maxVal: 100

    property bool ddcEverOk: false

    property int ddcBus: -1

    property int pendingPct: -1

    property bool busFallbackTried: false

    readonly property int writeCooldownMs: 4000
    property double lastWriteDoneAt: 0

    readonly property bool supportsLiveDrag: brightnessModule.backend === "sysfs"
    readonly property int liveDragIntervalMs: 50

    property bool preview: false

    shown: brightnessModule.preview || (qsRoot.showBrightness && brightnessModule.backend !== "")

    readonly property bool ddcBusy: brightnessRead.running || brightnessWrite.running

    function stepPct(d, how) {
        brightnessModule.setPct(brightnessModule.pct + d, how);
    }

    function ddcArgs() {
        const base = ["ddcutil"];
        if (brightnessModule.ddcBus >= 0)
            base.push("--bus", String(brightnessModule.ddcBus));

        base.push("--sleep-multiplier", "0.2");
        return base;
    }

    function flushPending() {
        if (brightnessModule.pendingPct < 0 || brightnessModule.ddcBusy)
            return;
        const p = brightnessModule.pendingPct;
        brightnessModule.pendingPct = -1;
        brightnessModule.writePct(p, "flush");
    }

    function writePct(p, how) {
        if (brightnessModule.preview && brightnessModule.backend === "") {
            console.log("[BRIGHT] preview mode, display only, no backend write");
            return;
        }
        if (brightnessModule.backend === "sysfs") {
            if (brightnessModule.sysfsDev === "") {
                brightnessModule.refresh();
                return;
            }

            const v = Math.max(0, Math.round(brightnessModule.maxVal * p / 100));
            brightnessWrite.command = ["bash", "-c", "busctl call org.freedesktop.login1 /org/freedesktop/login1/session/self " + "org.freedesktop.login1.Session SetBrightness ssu backlight " + brightnessModule.sysfsDev + " " + v];
            brightnessWrite.running = true;
            writeWatchdog.restart();
            return;
        }

        const gap = Date.now() - brightnessModule.lastWriteDoneAt;
        if (gap < brightnessModule.writeCooldownMs) {
            brightnessModule.pendingPct = p;
            writeCooldownTimer.interval = brightnessModule.writeCooldownMs - gap + 100;
            writeCooldownTimer.restart();
            return;
        }
        brightnessWrite.command = brightnessModule.ddcArgs().concat(["setvcp", "10", String(p)]);
        brightnessWrite.running = true;
        writeWatchdog.restart();
    }
    function setPct(p, how) {
        p = Math.round(p);
        if (!(p >= 0 && p <= 100)) {
            console.log("[BRIGHT] " + how + " out of range: " + p);
            return;
        }
        if (brightnessModule.backend === "" && !brightnessModule.preview)
            return;
        if (brightnessModule.backend === "" && brightnessModule.preview) {
            brightnessModule.pct = p;
            console.log("[BRIGHT] " + how + " → " + p + "%");
            brightnessModule.writePct(p, how);
            return;
        }
        if (brightnessModule.pct < 0) {
            brightnessModule.pendingPct = p;
            brightnessModule.refresh();
            return;
        }
        if (brightnessModule.ddcBusy) {
            if (p === brightnessModule.pendingPct) {
                brightnessModule.pct = p;
                return;
            }
            if (p === brightnessModule.pct) {
                brightnessModule.pendingPct = -1;
                return;
            }
            brightnessModule.pendingPct = p;
            brightnessModule.pct = p;
            if (how !== "popup-drag")
                console.log("[BRIGHT] " + how + " → " + p + "% (queued)");
            return;
        }
        if (p === brightnessModule.pct) {
            if (brightnessModule.pendingPct !== p)
                brightnessModule.pendingPct = -1;
            return;
        }
        brightnessModule.pct = p;
        if (how !== "popup-drag")
            console.log("[BRIGHT] " + how + " → " + p + "%");
        brightnessModule.writePct(p, how);
    }

    function refresh() {
        if (brightnessModule.backend === "" || brightnessModule.ddcBusy)
            return;
        if (brightnessModule.backend === "sysfs") {
            brightnessRead.command = ["bash", "-c", "d=$(ls -d /sys/class/backlight/* | head -1); " + "echo \"${d##*/}\"; cat \"$d/brightness\" \"$d/max_brightness\""];
        } else {
            brightnessRead.command = brightnessModule.ddcArgs().concat(["getvcp", "10", "--brief"]);
        }
        brightnessRead.running = true;
        readWatchdog.restart();
    }

    Process {
        id: brightnessProbe
        running: true
        command: ["bash", "-c", "for d in /sys/class/backlight/*; do [ -d \"$d\" ] && { echo sysfs; exit 0; }; done; " + "command -v ddcutil >/dev/null 2>&1 || exit 0; " + "bus=$(ddcutil detect 2>/dev/null | grep -m1 \"I2C bus\" | sed \"s/.*i2c-//\" | tr -d \"[:space:]\"); " + "[ -n \"$bus\" ] && echo \"ddc $bus\" || echo ddc"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                if (t.indexOf("sysfs") === 0) {
                    brightnessModule.backend = "sysfs";
                    brightnessModule.refresh();
                } else if (t.indexOf("ddc") === 0) {
                    const bus = Number(t.split(/\s+/)[1]);
                    brightnessModule.ddcBus = isFinite(bus) ? bus : -1;
                    brightnessModule.backend = "ddc";
                    brightnessModule.refresh();
                }
            }
        }
    }

    Process {
        id: brightnessRead

        onExited: brightnessModule.flushPending()
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n").filter(s => s !== "");
                if (brightnessModule.backend === "sysfs") {
                    if (lines.length < 3) {
                        console.log("[BRIGHT] brightness read failed");
                        return;
                    }
                    const cur = Number(lines[1]), max = Number(lines[2]);
                    if (!isFinite(cur) || !isFinite(max) || max <= 0) {
                        console.log("[BRIGHT] brightness read failed");
                        return;
                    }
                    brightnessModule.sysfsDev = lines[0];
                    brightnessModule.maxVal = max;
                    brightnessModule.pct = Math.round(cur / max * 100);
                } else {
                    const vcp = lines.find(s => s.indexOf("VCP 10") === 0);
                    if (vcp === undefined) {
                        if (!brightnessModule.ddcEverOk && brightnessModule.ddcBus >= 0 && !brightnessModule.busFallbackTried) {
                            brightnessModule.busFallbackTried = true;
                            console.log("[BRIGHT] --bus " + brightnessModule.ddcBus + " read failed, fall back to full-probe form and retry; raw output: " + text.trim().slice(0, 160));
                            brightnessModule.ddcBus = -1;

                            Qt.callLater(brightnessModule.refresh);
                            return;
                        }
                        if (!brightnessModule.ddcEverOk) {
                            console.log("[BRIGHT] ddcutil can't read VCP 10 (no DDC/CI on monitor?), hiding; raw output: " + text.trim().slice(0, 160));
                            brightnessModule.backend = "";
                        } else {
                            console.log("[BRIGHT] ddcutil read failed, keep old value");
                        }
                        return;
                    }
                    const f = vcp.trim().split(/\s+/);
                    const cur = Number(f[3]), max = Number(f[4]);
                    if (!isFinite(cur) || !isFinite(max) || max <= 0)
                        return;
                    brightnessModule.ddcEverOk = true;
                    brightnessModule.busFallbackTried = false;
                    brightnessModule.pct = Math.round(cur / max * 100);
                }
                brightnessModule.flushPending();
            }
        }
    }

    Process {
        id: brightnessWrite

        onExited: code => {
            brightnessModule.lastWriteDoneAt = Date.now();
            if (code !== 0) {
                console.log("[BRIGHT] brightness write failed (exit code " + code + "), re-read to reconcile after cooldown");
                brightnessModule.refresh();
            }
            brightnessModule.flushPending();
        }
    }

    Timer {
        id: readWatchdog
        interval: 12000
        onTriggered: if (brightnessRead.running) {
            console.log("[BRIGHT] read timeout (12s), force kill");
            brightnessRead.running = false;
        }
    }
    Timer {
        id: writeWatchdog
        interval: 12000
        onTriggered: if (brightnessWrite.running) {
            console.log("[BRIGHT] write timeout (12s), force kill");
            brightnessWrite.running = false;
        }
    }

    Timer {
        id: writeCooldownTimer
        onTriggered: brightnessModule.flushPending()
    }

    onClicked: brightnessPopup.open()

    wheelEnabled: true
    onWheelNotch: d => brightnessModule.stepPct(d * 5, "wheel")

    Text {
        id: brightIcon
        anchors.centerIn: parent

        color: brightnessModule.preview && brightnessModule.backend === "" ? Style.text3 : Style.text2
        font.family: Style.nerd
        font.pixelSize: 18

        text: "\u{F00E0}"
    }
}
