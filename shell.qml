//@ pragma UseQApplication

import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.Polkit
import Quickshell.Wayland
import Quickshell.Wayland._IdleInhibitor
import "components"

ShellRoot {
    id: qsRoot

    readonly property alias rootRef: qsRoot
    readonly property alias weatherRef: weather
    readonly property alias notifCenterRef: notifCenter
    readonly property var powerFlowRef: powerFlow

    property bool showTerminal: false
    property bool showBrowser: false
    property bool showFilemanager: false
    property bool showTemperature: false
    property bool showDisk: false
    property bool showCpu: false
    property bool showMemory: false

    property bool showIdleInhibitor: false
    property bool showMpris: false
    property bool showPpd: false
    property bool showKeyboard: false
    property bool showLanguage: false
    property bool showPrivacy: true
    property bool showClips: false
    property bool showPomodoro: true

    property bool showBattery: Style.laptopBattery() !== null
    property bool showNetIface: false
    property bool showBtDevice: false
    property int clipMaxEntries: 50
    property bool showNetSpeed: false
    property bool showWallpaper: false
    property bool autoTheme: false
    property bool showClockSeconds: false
    property bool clock24: true

    property bool showLunar: false

    property bool showWeather: false

    property bool showReboot: false

    property bool showBrightness: false

    property int pomodoroFocusMin: 25
    property int pomodoroBreakMin: 5
    property int pomodoroLongMin: 15
    property int pomodoroLongEvery: 4
    property int idleLockMinutes: 5
    property int idleDpmsMinutes: 10

    property bool idleInhibited: false

    property bool fullscreenDnd: true

    property bool fullscreenIdleInhibit: false

    property bool launcherEmptyWs: true

    ScreenPanels {
        id: screenPanels
    }

    Item {
        id: powerFlow

        property var blockInhibitors: []
        readonly property bool hasBlockers: blockInhibitors.length > 0

        readonly property string blockerNames: blockInhibitors.map(b => b.who).join(I18n.effectiveLang === "zh" ? "、" : ", ")

        property bool notifyAfterProbe: false

        property string pendingOp: "poweroff"

        property int myUid: -1

        Component.onCompleted: if (!uidProc.running)
            uidProc.running = true

        Process {
            id: uidProc
            command: ["sh", "-c", "id -u"]
            running: false
            stdout: StdioCollector {
                onStreamFinished: {
                    const n = parseInt(String(text).trim());
                    powerFlow.myUid = Number.isNaN(n) ? -1 : n;
                }
            }
        }

        Process {
            id: inhibitProbe
            command: ["busctl", "call", "--json=short", "org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager", "ListInhibitors"]
            stdout: StdioCollector {
                onStreamFinished: {
                    let list = null;
                    try {
                        list = [];

                        for (const it of JSON.parse(text).data[0])
                            if (it.length >= 4 && it[3] === "block" && String(it[0]).split(":").indexOf("shutdown") >= 0)
                                list.push({
                                    what: String(it[0]),
                                    who: String(it[1]),
                                    mode: String(it[3]),
                                    uid: it.length > 4 ? Number(it[4]) : -1,
                                    pid: it.length > 5 ? Number(it[5]) : -1
                                });
                    } catch (e) {
                        list = null;
                    }
                    if (list !== null) {
                        powerFlow.blockInhibitors = list;
                        powerFlow.blockersFreshAt = Date.now();
                    }

                    if (list !== null) {
                        if (powerFlow.pendingForceOp !== "")
                            powerFlow.resolveForce(true);
                        else if (powerFlow.graceful)
                            powerFlow.gracefulEvaluate();
                        else if (powerFlow.notifyAfterProbe) {
                            powerFlow.notifyAfterProbe = false;
                            powerFlow.notifyBlocked();
                        }
                    }
                }
            }

            onExited: code => {
                if (powerFlow.pendingForceOp !== "" && code !== 0) {
                    powerFlow.resolveForce(false);
                } else if (powerFlow.graceful && code !== 0) {
                    powerFlow.gracefulEvaluate();
                } else if (powerFlow.notifyAfterProbe && code !== 0) {
                    powerFlow.notifyAfterProbe = false;
                    powerFlow.notifyBlocked();
                }
            }
        }

        function notifyBlocked() {
            notifyWatchdog.stop();
            const names = powerFlow.blockerNames;
            const op = powerFlow.pendingOp === "reboot" ? "reboot" : "poweroff";
            const actionId = op + "-force";
            const actionLabel = I18n.t(op === "reboot" ? "power.forceReboot" : "power.forcePoweroff");
            if (blockedNotifyProc.running)
                return;

            const title = names !== "" ? I18n.t("power.inhibit") : I18n.t("power.failed");
            const body = names !== "" ? I18n.t("power.inhibitBody") + names : I18n.t("power.failedBody");
            blockedNotifyProc.command = ["gdbus", "call", "--timeout", "3", "--session", "--dest", "org.freedesktop.Notifications", "--object-path", "/org/freedesktop/Notifications", "--method", "org.freedesktop.Notifications.Notify", "quickshell", "0", "", title, body, "[" + Style.gvStr(actionId) + ", " + Style.gvStr(actionLabel) + "]", "{\"urgency\": <byte 2>, \"x-quickshell-power\": <\"" + op + "\">}", 20000];
            blockedNotifyProc.running = true;
        }

        Process {
            id: blockedNotifyProc
            stderr: StdioCollector {
                onStreamFinished: {
                    if (text.trim() !== "")
                        console.log("[POWER] blocked-notify stderr: " + text.trim());
                }
            }
            onExited: code => {
                if (code !== 0)
                    console.log("[POWER] blocked-notify failed, gdbus exit " + code);
            }
        }

        function probeBlockersThenNotify() {
            powerFlow.notifyAfterProbe = true;
            notifyWatchdog.restart();
            if (!inhibitProbe.running)
                inhibitProbe.running = true;
        }

        Timer {
            id: notifyWatchdog
            interval: 1500
            onTriggered: {
                if (powerFlow.notifyAfterProbe) {
                    powerFlow.notifyAfterProbe = false;
                    powerFlow.notifyBlocked();
                }
            }
        }

        function probeBlockers() {
            if (!inhibitProbe.running)
                inhibitProbe.running = true;
        }
        function blockersDump() {
            return JSON.stringify(powerFlow.blockInhibitors);
        }

        property var graceful: null
        readonly property int gracefulTermMs: 6000
        readonly property int gracefulKillMs: 10000

        property real blockersFreshAt: 0

        property string pendingForceOp: ""

        function requestGracefulForce(op) {
            powerFlow.pendingForceOp = op;
            forceWatchdog.restart();

            if (powerFlow.myUid < 0 && !uidProc.running)
                uidProc.running = true;
            if (!inhibitProbe.running)
                inhibitProbe.running = true;
        }

        function resolveForce(fresh) {
            const op = powerFlow.pendingForceOp;
            powerFlow.pendingForceOp = "";
            forceWatchdog.stop();
            if (op === "")
                return;

            powerFlow.graceful = null;
            gracefulTick.stop();
            if (!fresh) {
                powerFlow.forceFallback(op);
                return;
            }
            if (powerFlow.blockInhibitors.length === 0) {
                powerFlow.run(op === "reboot" ? "systemctl reboot" : "systemctl poweroff");
                return;
            }
            if (powerFlow.gracefulForce(op))
                return;
            powerFlow.forceFallback(op);
        }

        function forceFallback(op) {
            powerFlow.pendingOp = op;

            if (actionProc.running) {
                console.log("[POWER] fallback in flight, drop: " + op);
                return;
            }
            actionProc.command = ["bash", "-c", op === "reboot" ? "systemctl reboot -i" : "systemctl poweroff -i"];
            actionProc.running = true;
        }

        function gracefulForce(op) {
            const pids = Style.gracefulCandidates(powerFlow.blockInhibitors, powerFlow.myUid);
            if (pids.length === 0)
                return false;

            powerFlow.pendingOp = op;
            powerFlow.graceful = {
                op: op,
                phase: "term",
                started: Date.now()
            };
            gracefulKill("TERM", pids);
            gracefulTick.restart();
            return true;
        }

        function gracefulKill(sig, pids) {
            const cmd = ["bash", "-c", "kill -" + sig + " " + pids.join(" ") + " 2>/dev/null; true"];

            const p = sig === "TERM" ? termProc : killProc;
            if (!p.running) {
                p.command = cmd;
                p.running = true;
            }
        }

        function gracefulEvaluate() {
            const g = powerFlow.graceful;
            if (!g)
                return;
            if (!powerFlow.hasBlockers) {
                powerFlow.graceful = null;
                gracefulTick.stop();
                powerFlow.run(g.op === "reboot" ? "systemctl reboot" : "systemctl poweroff");
                return;
            }
            const elapsed = Date.now() - g.started;
            if (g.phase === "term" && elapsed >= powerFlow.gracefulTermMs) {
                g.phase = "kill";

                if (powerFlow.blockersFreshAt >= g.started) {
                    const pids = [];
                    for (const b of powerFlow.blockInhibitors)
                        if (b.pid > 0 && b.uid >= 0 && b.uid === powerFlow.myUid)
                            pids.push(b.pid);
                    if (pids.length > 0)
                        gracefulKill("KILL", pids);
                }
            }
            if (elapsed >= powerFlow.gracefulKillMs) {
                powerFlow.graceful = null;
                gracefulTick.stop();
                powerFlow.notifyBlocked();
                return;
            }
            gracefulTick.restart();
        }

        Timer {
            id: gracefulTick
            interval: 700
            onTriggered: {
                if (!powerFlow.graceful)
                    return;
                powerFlow.gracefulEvaluate();
                if (powerFlow.graceful && !inhibitProbe.running)
                    inhibitProbe.running = true;
            }
        }

        Timer {
            id: forceWatchdog
            interval: 1500
            onTriggered: {
                if (powerFlow.pendingForceOp !== "")
                    powerFlow.resolveForce(false);
            }
        }

        Process {
            id: termProc
            running: false
        }

        Process {
            id: killProc
            running: false
        }

        function run(cmd) {
            if (String(cmd).indexOf("systemctl poweroff") === 0 || String(cmd).indexOf("systemctl reboot") === 0) {
                powerFlow.pendingOp = String(cmd).indexOf("systemctl reboot") === 0 ? "reboot" : "poweroff";

                if (actionProc.running) {
                    console.log("[POWER] action still in flight, drop: " + cmd);
                    return;
                }
                actionProc.command = ["bash", "-c", cmd];
                actionProc.running = true;
                return;
            }
            Quickshell.execDetached(["bash", "-c", cmd]);
        }

        Process {
            id: actionProc
            onExited: code => {
                if (code === 0)
                    return;
                powerFlow.probeBlockersThenNotify();
            }
        }
    }

    property alias launcherByScreen: screenPanels.launcherByScreen
    property alias clipsByScreen: screenPanels.clipsByScreen
    property alias powerMenuByScreen: screenPanels.powerMenuByScreen
    property alias promptByScreen: screenPanels.promptByScreen
    property alias settingsByScreen: screenPanels.settingsByScreen
    property alias brightnessByScreen: screenPanels.brightnessByScreen
    property alias pomodoroByScreen: screenPanels.pomodoroByScreen
    property alias calendarByScreen: screenPanels.calendarByScreen
    property alias weatherPopupByScreen: screenPanels.weatherPopupByScreen
    property alias trayRowByScreen: screenPanels.trayRowByScreen

    function focusedScreenName() {
        if (Style.compositor === "niri")
            return Compositor.niriFocusedOutput;
        if (Style.compositor === "sway")
            return Compositor.swayFocusedOutput;
        try {
            return Hyprland.focusedMonitor ? String(Hyprland.focusedMonitor.name) : "";
        } catch (e) {
            return "";
        }
    }

    function launcherToggle() {
        const k = focusedScreenName();
        const cur = launcherByScreen[k] === true;
        screenPanels.setActive("launcher", k, !cur);
    }
    function launcherSet(v) {
        screenPanels.setActive("launcher", focusedScreenName(), v === true);
    }
    function clipsToggle() {
        const k = focusedScreenName();
        const cur = clipsByScreen[k] === true;
        screenPanels.setActive("clips", k, !cur);
    }
    function clipsSet(v) {
        screenPanels.setActive("clips", focusedScreenName(), v === true);
    }

    function panelToggle(role) {
        const k = focusedScreenName();
        screenPanels.setActive(role, k, !screenPanels.activeFlag(role, k));
    }
    function panelSet(role, v) {
        screenPanels.setActive(role, focusedScreenName(), v === true);
    }
    function weatherSetEdit(v) {
        if (v === true)
            weatherEditRequested = true;
        screenPanels.setActive("weather", focusedScreenName(), v === true);
    }
    property bool weatherEditRequested: false

    property string polkitScreenKey: ""

    function polkitHere(key) {
        const names = Quickshell.screens.map(s => String(s.name));
        if (qsRoot.polkitScreenKey !== "") {
            if (names.indexOf(qsRoot.polkitScreenKey) >= 0)
                return key === qsRoot.polkitScreenKey;
        }

        return names.length > 0 && key === names[0];
    }

    function polkitState() {
        const f = polkitAgent.flow;
        return JSON.stringify({
            registered: polkitAgent.isRegistered,
            agentActive: polkitAgent.isActive,
            hasFlow: !!f,
            message: f ? String(f.message) : "",
            actionId: f ? String(f.actionId) : "",
            responseRequired: f ? f.isResponseRequired : false,
            inputPrompt: f ? String(f.inputPrompt || "") : "",
            failed: f ? f.failed : false,
            completed: f ? f.isCompleted : false,
            successful: f ? f.isSuccessful : false,
            cancelled: f ? f.isCancelled : false,
            supplementary: f ? String(f.supplementaryMessage) : "",
            supplementaryIsError: f ? f.supplementaryIsError : false,
            screen: qsRoot.polkitScreenKey,
            prompts: Object.keys(qsRoot.promptByScreen).map(k => {
                const p = qsRoot.promptByScreen[k];
                return p ? (k + ": active=" + p.active + " shown=" + p.shown + " mapped=" + p.visible + " size=" + Math.round(p.width) + "x" + Math.round(p.height)) : (k + ": <gone>");
            })
        });
    }

    function panelForFocused(map) {
        return screenPanels.forFocused(map, qsRoot.focusedScreenName());
    }

    function brightnessIpcState() {
        const m = panelForFocused(brightnessByScreen);
        return m ? JSON.stringify({
            backend: m.backend,
            shown: m.shown,
            percent: m.pct,
            preview: m.preview
        }) : JSON.stringify({
            error: "focused screen has no bar"
        });
    }

    readonly property var barFlagList: [
        {
            key: "showNetSpeed",
            labelKey: "flag.showNetSpeed",
            group: "display"
        },
        {
            key: "showNetIface",
            labelKey: "flag.showNetIface",
            group: "display"
        },
        {
            key: "showBtDevice",
            labelKey: "flag.showBtDevice",
            group: "display"
        },
        {
            key: "showClockSeconds",
            labelKey: "flag.showClockSeconds",
            group: "display"
        },
        {
            key: "showLunar",
            labelKey: "flag.showLunar",
            group: "display"
        },
        {
            key: "clock24",
            labelKey: "flag.clock24",
            group: "display"
        },
        {
            key: "launcherEmptyWs",
            labelKey: "flag.launcherEmptyWs",
            group: "display"
        },
        {
            key: "showTerminal",
            labelKey: "flag.showTerminal",
            group: "module"
        },
        {
            key: "showBrowser",
            labelKey: "flag.showBrowser",
            group: "module"
        },
        {
            key: "showFilemanager",
            labelKey: "flag.showFilemanager",
            group: "module"
        },
        {
            key: "showTemperature",
            labelKey: "flag.showTemperature",
            group: "module"
        },
        {
            key: "showDisk",
            labelKey: "flag.showDisk",
            group: "module"
        },
        {
            key: "showCpu",
            labelKey: "flag.showCpu",
            group: "module"
        },
        {
            key: "showMemory",
            labelKey: "flag.showMemory",
            group: "module"
        },
        {
            key: "showIdleInhibitor",
            labelKey: "flag.showIdleInhibitor",
            group: "idle"
        },
        {
            key: "fullscreenIdleInhibit",
            labelKey: "flag.fullscreenIdleInhibit",
            group: "idle"
        },
        {
            key: "autoTheme",
            labelKey: "flag.autoTheme",
            group: "display",
            hidden: true
        },
        {
            key: "showWeather",
            labelKey: "flag.showWeather",
            group: "module"
        },
        {
            key: "showMpris",
            labelKey: "flag.showMpris",
            group: "module"
        },
        {
            key: "showPpd",
            labelKey: "flag.showPpd",
            group: "module"
        },
        {
            key: "showPrivacy",
            labelKey: "flag.showPrivacy",
            group: "module"
        },
        {
            key: "showWallpaper",
            labelKey: "flag.showWallpaper",
            group: "module"
        },
        {
            key: "showClips",
            labelKey: "flag.showClips",
            group: "module"
        },
        {
            key: "showReboot",
            labelKey: "flag.showReboot",
            group: "module"
        },
        {
            key: "showBrightness",
            labelKey: "flag.showBrightness",
            group: "module"
        },
        {
            key: "showBattery",
            labelKey: "flag.showBattery",
            group: "module"
        },
        {
            key: "showKeyboard",
            labelKey: "flag.showKeyboard",
            group: "module"
        },
        {
            key: "showLanguage",
            labelKey: "flag.showLanguage",
            group: "module"
        },
        {
            key: "showPomodoro",
            labelKey: "flag.showPomodoro",
            group: "module"
        },
        {
            key: "fullscreenDnd",
            labelKey: "flag.fullscreenDnd",
            group: "notif"
        }
    ]

    readonly property var showFlags: barFlagList.map(f => f.key)

    readonly property var numberSettings: [
        {
            key: "historyLimit",
            min: 5,
            max: 500,
            step: 5,
            read: () => notifCenter.historyLimit,
            write: v => notifCenter.historyLimit = v,
            after: () => notifCenter.applyHistoryLimit()
        },
        {
            key: "barHeight",
            min: 24,
            max: 48,
            step: 1,
            read: () => Style.barHeight,
            write: v => Style.barHeight = v
        },
        {
            key: "clipMaxEntries",
            min: 10,
            max: 200,
            step: 10,
            read: () => qsRoot.clipMaxEntries,
            write: v => qsRoot.clipMaxEntries = v
        },
        {
            key: "idleLockMinutes",
            min: 0,
            max: 60,
            step: 1,
            read: () => qsRoot.idleLockMinutes,
            write: v => qsRoot.idleLockMinutes = v
        },
        {
            key: "idleDpmsMinutes",
            min: 0,
            max: 60,
            step: 1,
            read: () => qsRoot.idleDpmsMinutes,
            write: v => qsRoot.idleDpmsMinutes = v
        },
        {
            key: "pomodoroFocusMin",
            min: 1,
            max: 60,
            step: 1,
            read: () => qsRoot.pomodoroFocusMin,
            write: v => qsRoot.pomodoroFocusMin = v
        },
        {
            key: "pomodoroBreakMin",
            min: 1,
            max: 30,
            step: 1,
            read: () => qsRoot.pomodoroBreakMin,
            write: v => qsRoot.pomodoroBreakMin = v
        },
        {
            key: "pomodoroLongMin",
            min: 5,
            max: 45,
            step: 5,
            read: () => qsRoot.pomodoroLongMin,
            write: v => qsRoot.pomodoroLongMin = v
        },
        {
            key: "pomodoroLongEvery",
            min: 2,
            max: 8,
            step: 1,
            read: () => qsRoot.pomodoroLongEvery,
            write: v => qsRoot.pomodoroLongEvery = v
        }
    ]
    function numberSetting(key) {
        for (const s of qsRoot.numberSettings)
            if (s.key === key)
                return s;
        return null;
    }

    function normalizeNumber(spec, raw) {
        if (typeof raw !== "number" || !isFinite(raw))
            return null;
        const stepped = Math.round(raw / spec.step) * spec.step;
        return Math.max(spec.min, Math.min(spec.max, stepped));
    }

    function restoreNumber(key, raw) {
        const s = qsRoot.numberSetting(key);
        if (!s)
            return;
        const v = qsRoot.normalizeNumber(s, raw);
        if (v !== null)
            s.write(v);
    }

    function applyNumberSetting(key, raw) {
        const s = qsRoot.numberSetting(key);
        if (!s)
            return;
        const v = qsRoot.normalizeNumber(s, raw);
        if (v === null || v === s.read())
            return;
        s.write(v);
        if (s.after)
            s.after();
        qsRoot.saveBarSettings();
    }

    readonly property var extraSettings: [
        {
            key: "idleInhibited",
            valid: v => typeof v === "boolean",
            read: () => qsRoot.idleInhibited,
            write: v => qsRoot.idleInhibited = v
        },
        {
            key: "dnd",
            valid: v => typeof v === "boolean",
            read: () => notifCenter.dnd,
            write: v => notifCenter.dnd = v
        },
        {
            key: "lang",
            valid: v => v === "auto" || I18n.langCodes.indexOf(v) >= 0,
            read: () => I18n.lang,
            write: v => I18n.lang = v
        },
        {
            key: "paletteName",
            valid: v => v === "auto" || Style.paletteIds.indexOf(v) >= 0,
            read: () => Style.paletteName,
            write: v => Style.paletteName = v
        },
        {
            key: "fontWarned",
            valid: v => typeof v === "boolean",
            read: () => qsRoot.fontWarned,
            write: v => qsRoot.fontWarned = v
        },
        {
            key: "brightnessWarned",
            valid: v => typeof v === "boolean",
            read: () => qsRoot.brightnessWarned,
            write: v => qsRoot.brightnessWarned = v
        }
    ]

    readonly property string home: Quickshell.env("HOME") || Quickshell.env("TMPDIR") || "/tmp"
    readonly property string stateDir: Style.stateDir

    function saveBarSettings() {
        if (!qsRoot.barSettingsLoaded) {
            qsRoot.barSettingsPending = true;
            return;
        }
        barSettingsStore.requestSave();
    }

    function setBarFlag(key, value) {
        if (qsRoot.showFlags.indexOf(key) < 0)
            return;
        qsRoot[key] = value;

        if (key === "showIdleInhibitor")
            qsRoot.idleInhibited = value === true;
        qsRoot.saveBarSettings();
    }

    function barSettingsObj() {
        const o = {};
        for (const k of qsRoot.showFlags)
            o[k] = qsRoot[k];
        for (const s of qsRoot.numberSettings)
            o[s.key] = s.read();
        for (const s of qsRoot.extraSettings)
            o[s.key] = s.read();
        return o;
    }

    function setHistoryLimit(v) {
        qsRoot.applyNumberSetting("historyLimit", v);
    }
    function setClipMaxEntries(v) {
        qsRoot.applyNumberSetting("clipMaxEntries", v);
    }
    function setBarHeight(v) {
        qsRoot.applyNumberSetting("barHeight", v);
    }
    function setIdleLockMinutes(v) {
        qsRoot.applyNumberSetting("idleLockMinutes", v);
    }
    function setIdleDpmsMinutes(v) {
        qsRoot.applyNumberSetting("idleDpmsMinutes", v);
    }
    function setPomodoroFocusMin(v) {
        qsRoot.applyNumberSetting("pomodoroFocusMin", v);
    }
    function setPomodoroBreakMin(v) {
        qsRoot.applyNumberSetting("pomodoroBreakMin", v);
    }
    function setPomodoroLongMin(v) {
        qsRoot.applyNumberSetting("pomodoroLongMin", v);
    }
    function setPomodoroLongEvery(v) {
        qsRoot.applyNumberSetting("pomodoroLongEvery", v);
    }

    function setIdleInhibited(v) {
        v = v === true;
        if (v === qsRoot.idleInhibited)
            return;
        qsRoot.idleInhibited = v;
        qsRoot.saveBarSettings();
    }

    function setLang(v) {
        if (v !== "auto" && I18n.langCodes.indexOf(v) < 0)
            return;
        if (v === I18n.lang)
            return;
        I18n.lang = v;
        qsRoot.saveBarSettings();
    }

    function cycleLang() {
        const order = ["auto"].concat(I18n.langCodes);
        qsRoot.setLang(order[(order.indexOf(I18n.lang) + 1) % order.length]);
    }

    function setPaletteName(v) {
        if (v !== "auto" && Style.paletteIds.indexOf(v) < 0)
            return;
        if (v === Style.paletteName)
            return;
        Style.paletteName = v;
        qsRoot.saveBarSettings();
    }

    function cyclePalette() {
        const order = ["auto"].concat(Style.paletteIds);
        qsRoot.setPaletteName(order[(order.indexOf(Style.paletteName) + 1) % order.length]);
    }

    Process {
        id: themeApply
        running: true
        command: ["sh", "-c", "exec " + Style.sq(Style.configDir + "/scripts/theme-apply.sh")]
        onExited: code => {
            if (code === 75) {
                themeApplyRetry.restart();
                return;
            }

            if (code === 76)
                console.log("[THEME] theme-apply partially applied (rc=76); " + "see the script's stderr for which step was skipped");
            if (qsRoot.themeApplyPending) {
                qsRoot.themeApplyPending = false;
                themeApply.running = true;
            }
        }
    }

    Timer {
        id: themeApplyRetry
        interval: 700
        repeat: false
        onTriggered: if (!themeApply.running)
            themeApply.running = true
    }

    property bool themeApplyPending: false
    function applyThemeNow() {
        if (themeApply.running) {
            qsRoot.themeApplyPending = true;
            return;
        }
        themeApply.running = true;
    }

    Connections {
        target: Style
        function onColorSchemeChanged() {
            qsRoot.applyThemeNow();
        }

        function onColorSchemeValueChanged() {
            qsRoot.applyThemeNow();
        }

        function onGtkThemeChanged() {
            qsRoot.applyThemeNow();
        }
    }

    JsonStore {
        id: barSettingsStore
        path: qsRoot.stateDir + "/bar-settings.json"
        defaultText: "{}"

        serialize: () => JSON.stringify(qsRoot.barSettingsObj())
        onSaveFailed: (code, failures) => console.warn("[QS] bar-settings save failed, exitCode " + code)
        onTextLoaded: text => {
            let saved = {};
            let parseOk = true;
            try {
                saved = JSON.parse(text);
            } catch (e) {
                parseOk = false;
            }

            if (!saved || typeof saved !== "object" || Array.isArray(saved)) {
                saved = {};
                if (text.trim() !== "" && text.trim() !== "{}")
                    parseOk = false;
            }
            if (!parseOk) {
                console.warn("[QS] bar-settings JSON is corrupt; quarantining as .corrupt");

                barSettingsQuarantine.running = true;
            }
            for (const k of qsRoot.showFlags)
                if (saved[k] !== undefined)
                    qsRoot[k] = saved[k] === true;

            for (const s of qsRoot.numberSettings)
                if (saved[s.key] !== undefined)
                    qsRoot.restoreNumber(s.key, saved[s.key]);

            for (const s of qsRoot.extraSettings)
                if (saved[s.key] !== undefined && s.valid(saved[s.key]))
                    s.write(saved[s.key]);

            if (!qsRoot.showIdleInhibitor)
                qsRoot.idleInhibited = false;

            qsRoot.barSettingsLoaded = true;

            qsRoot.checkFonts();
            if (qsRoot.barSettingsPending) {
                qsRoot.barSettingsPending = false;
                qsRoot.saveBarSettings();
            }
            qsRoot.settleHistoryLimit();
        }
    }

    Process {
        id: barSettingsQuarantine
        running: false
        command: ["sh", "-c", "mv -f " + Style.sq(qsRoot.stateDir + "/bar-settings.json") + " " + Style.sq(qsRoot.stateDir + "/bar-settings.json.corrupt")]
        onExited: code => {
            if (code !== 0) {
                console.warn("[QS] could not quarantine corrupt bar-settings, exit " + code);
                return;
            }

            if (qsRoot.barSettingsLoaded)
                qsRoot.saveBarSettings();
        }
    }

    Connections {
        target: notifCenter
        function onDndChanged() {
            if (qsRoot.barSettingsLoaded)
                qsRoot.saveBarSettings();
        }
    }

    property bool barSettingsLoaded: false
    property bool barSettingsPending: false

    property bool fontWarned: false
    function checkFonts() {
        if (!qsRoot.barSettingsLoaded)
            return;
        if (qsRoot.fontWarned)
            return;
        if (Style.nerd !== "")
            return;
        qsRoot.fontWarned = true;
        qsRoot.saveBarSettings();

        fontWarnNotify.restart();
    }
    Timer {
        id: fontWarnNotify
        interval: 2500
        repeat: false

        onTriggered: Style.notifySimple(I18n.t("font.noNerdTitle"), I18n.t("font.noNerdBody"), 10000)
    }

    property bool brightnessWarned: false
    property string brightnessWarnReason: ""

    property bool brightnessWarnPending: false
    function brightnessProbeGaveUp(reason) {
        if (!qsRoot.barSettingsLoaded)
            return;
        if (qsRoot.brightnessWarned)
            return;
        if (qsRoot.brightnessWarnPending)
            return;
        if (!qsRoot.showBrightness)
            return;
        qsRoot.brightnessWarnPending = true;
        qsRoot.brightnessWarnReason = String(reason || "");
        brightnessWarnNotify.restart();
    }
    Timer {
        id: brightnessWarnNotify
        interval: 1500
        repeat: false
        onTriggered: {
            qsRoot.brightnessWarnPending = false;
            const ddc = qsRoot.brightnessWarnReason === "no-ddc";

            Style.notifySimple(I18n.t("brightness.noBackendTitle"), I18n.t(ddc ? "brightness.noDdcBody" : "brightness.noToolBody"), 10000);

            qsRoot.brightnessWarned = true;
            qsRoot.saveBarSettings();
        }
    }

    function settleHistoryLimit() {
        if (qsRoot.barSettingsLoaded && notifCenter.historyLoaded) {
            notifCenter.historySettled = true;
            notifCenter.applyHistoryLimit();
        }
    }
    Connections {
        target: notifCenter
        function onHistoryLoadedChanged() {
            qsRoot.settleHistoryLimit();
        }
    }

    function btToggle(how) {
        const want = !Style.btOn;
        const via = Style.btSetEnabled(want);
        if (Style.debug)
            console.log("[BT] " + how + " toggle bt → " + (want ? "on" : "off") + "(via " + via + ")");
        return JSON.stringify({
            enabled: want,
            via: via
        });
    }

    function audioToggleMute(how) {
        const sink = Pipewire.defaultAudioSink;
        const audio = (sink && sink.audio) ? sink.audio : null;
        if (!audio) {
            if (Style.debug)
                console.log("[VOL] " + how + " toggle mute: no default output yet, no-op");
            return JSON.stringify({
                muted: null
            });
        }
        audio.muted = !audio.muted;
        if (Style.debug)
            console.log("[VOL] " + how + " toggle mute → " + (audio.muted ? "muted" : "unmuted"));
        return JSON.stringify({
            muted: audio.muted
        });
    }

    function audioStep(step, how) {
        const sink = Pipewire.defaultAudioSink;
        const audio = (sink && sink.audio) ? sink.audio : null;
        if (!audio) {
            if (Style.debug)
                console.log("[VOL] " + how + " step: no default output yet, no-op");
            return;
        }
        const cur = Number(audio.volume) || 0;
        const v = Math.min(1, Math.max(0, cur + step / 100));

        if (step > 0 && audio.muted)
            audio.muted = false;
        if (v === cur)
            return;
        audio.volume = v;
        if (Style.debug)
            console.log("[VOL] " + how + " " + (step > 0 ? "+" : "") + step + "% → " + Math.round(v * 100) + "%");
    }

    function netToggle(how) {
        const r = Style.netToggleLink();
        if (Style.debug)
            console.log("[NET] " + how + " net disconnect/reconnect(fallback) → " + r);
        return r;
    }
    function netToggleWifi(how) {
        const r = Style.netToggleWifiLink();
        if (Style.debug)
            console.log("[NET] " + how + " wifi cell → " + r);
        return r;
    }
    function netToggleWired(how) {
        const r = Style.netToggleWiredLink();
        if (Style.debug)
            console.log("[NET] " + how + " wired cell → " + r);
        return r;
    }

    function rebootNotice(kernelN, modulesN, libsN, detail) {
        const d = detail || {};
        const sep = I18n.t("reboot.sepList");
        function namesText(names, max) {
            const list = names || [];
            if (list.length === 0)
                return "";
            const shown = list.slice(0, max).join(sep);
            return list.length > max ? shown + " " + I18n.fill(I18n.t("reboot.moreItems"), {
                n: list.length - max
            }) : shown;
        }
        const lines = [];

        const kernelNames = (d.kernel && d.kernel.length > 0) ? d.kernel : [];
        if (kernelNames.length > 0)
            lines.push(I18n.fill(I18n.t("reboot.kernelItems"), {
                names: namesText(kernelNames, 1)
            }));
        else if (kernelN > 0)
            lines.push(I18n.fill(I18n.t("reboot.kernelCount"), {
                n: kernelN
            }));
        const moduleNames = (d.modules && d.modules.length > 0) ? d.modules : [];
        if (moduleNames.length > 0)
            lines.push(I18n.fill(I18n.t("reboot.moduleItems"), {
                names: namesText(moduleNames, 2)
            }));
        else if (modulesN > 0)
            lines.push(I18n.fill(I18n.t("reboot.moduleCount"), {
                n: modulesN
            }));
        const libNames = (d.libs && d.libs.length > 0) ? d.libs : [];
        if (libNames.length > 0) {
            const files = libsN > 1 ? I18n.fill(I18n.t("reboot.fileCount"), {
                n: libsN
            }) : "";
            lines.push(I18n.fill(I18n.t("reboot.libItems"), {
                names: namesText(libNames, 3),
                files: files
            }));
        } else if (libsN > 0) {
            lines.push(I18n.fill(I18n.t("reboot.libCount"), {
                n: libsN
            }));
        }

        return {
            title: (kernelN > 0 || modulesN > 0) ? I18n.t("reboot.title") : I18n.t("reboot.reloginTitle"),
            body: lines.join("\n")
        };
    }

    function rebootAction(kernelN, modulesN) {
        const wantReboot = kernelN > 0 || modulesN > 0;
        return {
            id: wantReboot ? "reboot" : "relogin",
            label: wantReboot ? I18n.t("reboot.action") : I18n.t("reboot.reloginAction"),
            icon: wantReboot ? "system-reboot" : "system-log-out",
            command: wantReboot ? "systemctl reboot" : "loginctl terminate-user \"$USER\""
        };
    }

    function notifyReboot(how) {
        if (!rebootNeeded.needs) {
            console.log("[REBOOT] " + how + ": no reboot/relogin needed now, no notification");
            return;
        }

        const notice = qsRoot.rebootNotice(rebootNeeded.newerKernel.length, rebootNeeded.newerModules.length, rebootNeeded.staleLibs.length, rebootNeeded.noticeDetail);
        console.log("[REBOOT] " + how + " notify: kernel " + rebootNeeded.newerKernel.length + " / modules " + rebootNeeded.newerModules.length + " / userland libs " + rebootNeeded.staleLibs.length);

        const action = qsRoot.rebootAction(rebootNeeded.newerKernel.length, rebootNeeded.newerModules.length);

        if (rebootNotifyProc.running)
            return;
        rebootNotifyProc.command = ["gdbus", "call", "--timeout", "3", "--session", "--dest", "org.freedesktop.Notifications", "--object-path", "/org/freedesktop/Notifications", "--method", "org.freedesktop.Notifications.Notify", "quickshell", "0", action.icon, notice.title, notice.body, "[" + Style.gvStr(action.id) + ", " + Style.gvStr(action.label) + "]", "{\"x-quickshell-reboot\": <\"1\">}", "5000"];
        rebootNotifyProc.running = true;
    }

    Process {
        id: rebootNotifyProc
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "")
                    console.log("[REBOOT] notify stderr: " + text.trim());
            }
        }
        onExited: code => {
            if (code !== 0)
                console.log("[REBOOT] notify failed, gdbus exit " + code);
        }
    }

    function rebootActionRoute(identifier) {
        if (identifier === "reboot") {
            powerFlow.run("systemctl reboot");
            return true;
        }
        if (identifier === "relogin") {
            Quickshell.execDetached(["bash", "-c", "loginctl terminate-user \"$USER\""]);
            return true;
        }
        return false;
    }

    function forceActionRoute(identifier) {
        const op = identifier === "reboot-force" ? "reboot" : identifier === "poweroff-force" ? "poweroff" : "";
        if (op === "")
            return false;
        powerFlow.requestGracefulForce(op);
        return true;
    }

    function pomodoroActionRoute(identifier) {
        if (identifier !== "pause")
            return false;
        const mods = qsRoot.pomodoroByScreen;
        for (const k of Object.keys(mods))
            if (mods[k] && mods[k].running)
                mods[k].pause();
        return true;
    }

    function notificationActionRoute(identifier) {
        return qsRoot.rebootActionRoute(identifier) || qsRoot.forceActionRoute(identifier) || qsRoot.pomodoroActionRoute(identifier);
    }

    LockScreen {
        id: lockScreen
        idleLockMinutes: qsRoot.idleLockMinutes
        idleDpmsMinutes: qsRoot.idleDpmsMinutes

        idleSuppressed: qsRoot.idleInhibited || (qsRoot.fullscreenIdleInhibit && Compositor.fullscreenActive)
    }

    PolkitAgent {
        id: polkitAgent
    }

    Connections {
        target: polkitAgent
        function onIsRegisteredChanged() {
            console.log("[POLKIT] agent registered " + (polkitAgent.isRegistered ? "ok" : "failed —— may be taken by another agent (hyprpolkitagent?)"));
        }

        function onFlowChanged() {
            qsRoot.polkitScreenKey = polkitAgent.flow ? qsRoot.focusedScreenName() : "";
            if (polkitAgent.flow)
                console.log("[POLKIT] received auth request: " + String(polkitAgent.flow.message) + " / " + String(polkitAgent.flow.actionId));
        }
    }

    Wallpaper {
        id: wallpaperBg
    }

    NotificationCenter {
        id: notifCenter

        fullscreenDnd: qsRoot.fullscreenDnd
    }

    Weather {
        id: weather
        enabled: qsRoot.showWeather
    }

    ThemeAuto {
        qsRoot: qsRoot
        weather: weather
    }

    RebootNeeded {
        id: rebootNeeded
        enabled: qsRoot.showReboot
    }

    IpcPanels {
        qsRoot: qsRoot
        notifCenter: notifCenter
    }
    IpcSystem {
        qsRoot: qsRoot
        lockScreen: lockScreen
        polkitAgent: polkitAgent
        rebootNeeded: rebootNeeded
    }
    IpcDiag {
        qsRoot: qsRoot
        screenPanels: screenPanels
    }

    Variants {
        model: Quickshell.screens

        delegate: Item {
            id: screenRoot

            required property var modelData

            property string screenKey: ""

            readonly property alias panelRef: panel
            readonly property alias weatherModuleRef: weatherModule
            readonly property alias wallpaperModuleRef: wallpaperModule
            readonly property alias clockModuleRef: clockModule
            readonly property alias brightnessModuleRef: brightnessModule
            readonly property alias brightnessPopupRef: brightnessPopup
            readonly property alias wifiModuleRef: wifiModule
            readonly property alias wiredModuleRef: wiredModule

            Component.onCompleted: {
                screenRoot.screenKey = modelData ? String(modelData.name) : "";

                screenPanels.register(screenRoot.screenKey, {
                    brightness: brightnessModule,
                    pomodoro: pomodoroModuleRef,
                    prompt: polkitPrompt,
                    tray: trayModule.trayRowItem
                });
            }
            Component.onDestruction: screenPanels.unregister(screenRoot.screenKey)

            PanelWindow {
                id: panel
                screen: screenRoot.modelData

                implicitWidth: screen ? screen.width : 1920

                implicitHeight: Style.barHeight

                anchors.top: true
                anchors.left: true
                anchors.right: true

                exclusiveZone: Style.barHeight

                WlrLayershell.layer: WlrLayer.Top
                color: Style.bg

                IdleInhibitor {
                    enabled: qsRoot.fullscreenIdleInhibit && Compositor.fullscreenActive
                    window: panel
                }

                Row {
                    id: leftRow
                    anchors.left: parent.left
                    anchors.leftMargin: 1
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    BarButton {
                        id: appmenuBtn
                        glyph: "\uF40E"
                        glyphSize: 20

                        padH: 11
                        marginLeft: 4
                        bgColor: "transparent"
                        rad: 5
                        marginRight: 0
                        glyphYOffset: 2

                        onClicked: launcherToggle()
                    }

                    Item {
                        width: 1
                        height: 1
                    }

                    Rectangle {
                        id: workspacesBox
                        width: workspacesRow.implicitWidth + 4
                        height: Style.barContentHeight
                        radius: 8
                        color: "transparent"

                        border.width: 1
                        border.color: "#3394a3b8"

                        opacity: 1.0

                        Row {
                            id: workspacesRow
                            objectName: "workspacesRow"
                            anchors.centerIn: parent
                            spacing: 4

                            Repeater {

                                model: Compositor.stripCount(screenRoot.screenKey)
                                delegate: WorkspaceButton {
                                    wsId: index + 1
                                    outputName: screenRoot.screenKey
                                    dragHost: dragHostRef
                                }
                            }
                        }

                        Item {
                            id: dragHostRef
                            anchors.fill: parent
                            z: 50
                            visible: dragActive
                            property bool dragActive: false
                            property var dragToplevel: null

                            property int dragFromWs: 0
                            property real ghostX: 0
                            function dragKeyOf(t) {
                                if (!t)
                                    return "";
                                if (t.address !== undefined)
                                    return String(t.address);
                                if (t.__wid !== undefined)
                                    return String(t.__wid);
                                return "";
                            }

                            Rectangle {
                                id: ghost
                                width: 30
                                height: 24
                                radius: 8
                                color: Style.withAlpha(Style.card, 0.92)
                                border.width: 1
                                border.color: Style.withAlpha(Style.accent, 0.6)
                                x: dragHostRef.ghostX - width / 2
                                anchors.verticalCenter: parent.verticalCenter

                                WindowIcon {
                                    anchors.centerIn: parent
                                    iconSize: 16
                                    toplevel: dragHostRef.dragToplevel
                                }
                            }

                            function beginDrag(toplevel, fromWs, gx) {
                                dragToplevel = toplevel;
                                dragFromWs = fromWs;
                                ghostX = gx;
                                dragActive = true;
                            }
                            function rowButtons() {
                                const out = {
                                    row: null,
                                    btns: []
                                };
                                const box = parent;
                                if (!box)
                                    return out;
                                for (let i = 0; i < box.children.length; i++) {
                                    const row = box.children[i];
                                    if (row.objectName !== "workspacesRow")
                                        continue;
                                    out.row = row;
                                    for (let j = 0; j < row.children.length; j++) {
                                        const b = row.children[j];
                                        if (b.wsId !== undefined)
                                            out.btns.push(b);
                                    }
                                    break;
                                }
                                return out;
                            }
                            function rowHit(gx) {
                                const r = rowButtons();
                                if (!r.row)
                                    return -1;
                                const x = gx - r.row.x;
                                for (const b of r.btns) {
                                    if (x >= b.x && x < b.x + b.width)
                                        return b.wsId;
                                }
                                return -1;
                            }
                            function moveGhost(gx) {
                                ghostX = gx;

                                const r = rowButtons();
                                if (!r.row)
                                    return;
                                const x = gx - r.row.x;
                                for (const b of r.btns)
                                    b.dropHover = dragActive && x >= b.x && x < b.x + b.width && b.wsId !== dragFromWs;
                            }

                            function cancelDrag() {
                                dragActive = false;
                                dragToplevel = null;
                                for (const b of rowButtons().btns)
                                    b.dropHover = false;
                            }
                            function dropAt(gx, gy) {
                                const tl = dragToplevel;
                                const from = dragFromWs;
                                const hit = rowHit(gx);
                                dragActive = false;
                                dragToplevel = null;
                                for (const b of rowButtons().btns)
                                    b.dropHover = false;

                                const key = dragKeyOf(tl);
                                if (hit > 0 && hit !== from && tl && key !== "") {
                                    const pt = mapToItem(null, gx, gy !== undefined ? gy : 16);
                                    Compositor.moveWindowToWorkspace(key, hit, pt.x, pt.y, screenRoot.screenKey);
                                }
                            }
                        }
                    }

                    Item {
                        width: 10
                        height: 1
                    }

                    BarButton {
                        shown: qsRoot.showTerminal
                        glyph: "\uF489"
                        glyphSize: 18
                        padH: 2
                        marginRight: 2
                        glyphYOffset: 1
                        onClicked: {
                            if (qsRoot.launcherEmptyWs)
                                Compositor.prepareEmptyWorkspaceForLaunch();
                            else
                                Compositor.clearPendingWsSwitch();

                            Style.probePanelApp([Style.terminal], Compositor.takePendingWsSwitch());
                        }
                    }

                    BarButton {
                        shown: qsRoot.showBrowser
                        glyph: "\uF269"
                        glyphSize: 20
                        padH: 2
                        marginRight: 2
                        glyphYOffset: 2

                        onClicked: {
                            if (qsRoot.launcherEmptyWs)
                                Compositor.prepareEmptyWorkspaceForLaunch();
                            else
                                Compositor.clearPendingWsSwitch();
                            const pre = Compositor.takePendingWsSwitch();

                            Quickshell.execDetached(["env", "QS_NOBROWSER=" + I18n.t("hint.noBrowser"), "QS_LAUNCHER=" + Style.configDir + "/scripts/launch-desktop.sh", "bash", "-c", (pre !== "" ? pre + "; " : "") + "id=$(xdg-settings get default-web-browser 2>/dev/null); " + "if [ -n \"$id\" ]; then \"$QS_LAUNCHER\" \"$id\" && exit 0; fi; " + "xdg-open about:blank 2>/dev/null && exit 0; " + "exec gdbus call --session --dest org.freedesktop.Notifications " + "--object-path /org/freedesktop/Notifications " + "--method org.freedesktop.Notifications.Notify " + "--timeout 3 " + "quickshell 0 \"\" \"$QS_NOBROWSER\" \"\" \"[]\" " + "'{\"urgency\": <byte 1>}' 4000"]);
                        }
                    }

                    BarButton {
                        shown: qsRoot.showFilemanager
                        glyph: "\uEA83"
                        glyphSize: 20

                        fontWeight: Font.Bold
                        padH: 2
                        marginRight: 10
                        glyphYOffset: 1

                        onClicked: {
                            if (qsRoot.launcherEmptyWs)
                                Compositor.prepareEmptyWorkspaceForLaunch();
                            else
                                Compositor.clearPendingWsSwitch();
                            const pre = Compositor.takePendingWsSwitch();
                            Quickshell.execDetached(["env", "QS_NOFM=" + I18n.t("hint.noFileManager"), "bash", "-c", (pre !== "" ? pre + "; " : "") + "xdg-open \"$HOME\" 2>/dev/null || exec gdbus call --session " + "--dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications " + "--method org.freedesktop.Notifications.Notify " + "--timeout 3 " + "quickshell 0 \"\" \"$QS_NOFM\" \"\" \"[]\" " + "'{\"urgency\": <byte 1>}' 4000"]);
                        }
                    }
                }

                Row {
                    id: titleRow

                    readonly property real gapLeft: leftRow.x + leftRow.width + 8
                    readonly property real gapRight: rightRow.x - 8

                    readonly property real availableWidth: Math.max(60, titleRow.gapRight - titleRow.gapLeft)

                    x: titleRow.gapLeft + Math.max(0, (titleRow.gapRight - titleRow.gapLeft - width) / 2)
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        id: titleText

                        property string pendingTitle: Compositor.activeTitle
                        property string shownTitle: ""
                        onPendingTitleChanged: {
                            if (Style.debug)
                                console.log("[TITLE] pending:", JSON.stringify(pendingTitle));

                            if (!titleDebounce.running)
                                titleDebounce.start();
                        }

                        Timer {
                            id: titleDebounce
                            interval: 250
                            onTriggered: titleText.shownTitle = titleText.pendingTitle
                        }

                        text: titleText.shownTitle
                        textFormat: Text.PlainText
                        color: Style.text1
                        font.family: Style.cjk
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                        maximumLineCount: 1

                        width: Math.min(implicitWidth, titleRow.availableWidth)

                        Component.onCompleted: {
                            if (Style.debug)
                                console.log("[TITLE] init:", JSON.stringify(pendingTitle), "compositor:", Style.compositor);
                            titleText.shownTitle = titleText.pendingTitle;
                        }
                    }
                }

                Row {
                    id: rightRow
                    anchors.right: parent.right
                    anchors.rightMargin: 1
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    BarButton {
                        glyph: "\uf2d4"
                        glyphSize: 20

                        padH: 3
                        marginRight: 3
                        glyphYOffset: 1
                        onClicked: Compositor.closeWindow()
                    }

                    MprisModule {
                        id: mprisModule
                        qsRoot: rootRef
                    }

                    BarButton {
                        id: tempModule

                        hoverTint: false
                        bgColor: "transparent"
                        rad: 4
                        padH: 2
                        marginRight: 2

                        glyphYOffset: 0
                        textColor: Style.text1
                        glyph: tempModule.critical ? "\uF2C7" : "\uF2C9"
                        glyphSize: 18

                        tailText: tempModule.celsius.toFixed(1) + "°"
                        tailSize: 14
                        tailGap: 3

                        property real celsius: 0
                        readonly property bool critical: celsius >= 80

                        readonly property bool hasTemp: !isNaN(celsius) && celsius > 0
                        shown: qsRoot.showTemperature && hasTemp

                        Poller {

                            active: qsRoot.showTemperature
                            interval: 5000
                            command: ["sh", "-c", "for d in /sys/class/hwmon/hwmon*; do " + "n=$(cat \"$d/name\" 2>/dev/null); " + "case \"$n\" in k10temp|coretemp|zenpower|cpu_thermal|cpu-thermal) " + "head -n1 \"$d\"/temp1_input 2>/dev/null; break ;; esac; done"]
                            onOutput: text => tempModule.celsius = parseInt(String(text).trim()) / 1000
                        }
                    }

                    BarButton {
                        id: diskModule
                        shown: qsRoot.showDisk
                        bgColor: "transparent"
                        rad: 5
                        padH: 2
                        marginRight: 2
                        glyphYOffset: 0
                        textColor: Style.text2
                        glyph: "\u{F02CA}"
                        glyphSize: 18
                        tailText: diskModule.pct + "%"
                        tailSize: 14
                        tailGap: 1

                        property int pct: 0

                        Poller {
                            active: qsRoot.showDisk
                            interval: 30000

                            timeoutMs: 10000
                            command: ["sh", "-c", "df -P / | tail -1"]
                            onOutput: text => {
                                const parts = String(text).trim().split(/\s+/);

                                if (parts.length >= 5 && isFinite(parseInt(parts[4])))
                                    diskModule.pct = parseInt(parts[4]) || 0;
                            }
                        }

                        onClicked: Style.probePanelApp([Style.terminal, "-e", "top"])
                    }

                    BarButton {
                        id: cpuModule
                        shown: qsRoot.showCpu
                        bgColor: "transparent"
                        rad: 5
                        padH: 2
                        marginRight: 2
                        glyphYOffset: 0
                        textColor: Style.text2
                        glyph: "\uF4BC"
                        glyphSize: 18

                        tailText: cpuModule.usage + "%"
                        tailSize: 14
                        tailGap: 2

                        property real usage: 0
                        property var last: null

                        Poller {
                            active: qsRoot.showCpu
                            interval: 2000
                            command: ["cat", "/proc/stat"]
                            onOutput: text => {
                                const parts = String(text).split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
                                if (parts.length < 5)
                                    return;
                                const idle = parts[3] + (parts[4] || 0);
                                const total = parts.reduce((a, b) => a + b, 0);
                                if (cpuModule.last) {
                                    const dTotal = total - cpuModule.last.total;
                                    const dIdle = idle - cpuModule.last.idle;
                                    if (dTotal > 0)
                                        cpuModule.usage = Math.round((1 - dIdle / dTotal) * 100);
                                }
                                cpuModule.last = {
                                    idle: idle,
                                    total: total
                                };
                            }
                        }

                        onClicked: Style.probePanelApp([Style.terminal, "-e", "top"])
                    }

                    BarButton {
                        id: memoryModule
                        shown: qsRoot.showMemory
                        bgColor: "transparent"
                        rad: 5
                        padH: 2

                        marginRight: 2
                        glyphYOffset: 0
                        textColor: Style.text2
                        glyph: "\uEFC5"
                        glyphSize: 18
                        tailText: memoryModule.usage + "%"
                        tailSize: 14
                        tailGap: 2

                        property real usage: 0

                        Poller {
                            active: qsRoot.showMemory
                            interval: 2000
                            command: ["cat", "/proc/meminfo"]
                            onOutput: text => {
                                let total = 0, avail = 0;
                                for (const l of String(text).split("\n")) {
                                    let m = l.match(/^MemTotal:\s+(\d+)/);
                                    if (m)
                                        total = +m[1];
                                    m = l.match(/^MemAvailable:\s+(\d+)/);
                                    if (m)
                                        avail = +m[1];
                                }
                                if (total > 0)
                                    memoryModule.usage = Math.round((total - avail) / total * 100);
                            }
                        }

                        onClicked: Style.probePanelApp([Style.terminal, "-e", "top"])
                    }

                    BarButton {
                        id: idleInhibitor
                        shown: qsRoot.showIdleInhibitor
                        glyph: qsRoot.idleInhibited ? "\u{F0176}" : "\u{F0FAA}"
                        glyphSize: 18

                        padH: 2
                        marginRight: 1
                        glyphYOffset: 1

                        opacityVal: 0.8

                        IdleInhibitor {

                            enabled: qsRoot.showIdleInhibitor && qsRoot.idleInhibited
                            window: panel
                        }

                        onClicked: qsRoot.setIdleInhibited(!qsRoot.idleInhibited)
                        onRightClicked: lockScreen.lockNow()
                    }

                    BarButton {
                        id: weatherModule
                        shown: qsRoot.showWeather
                        bgColor: "transparent"
                        rad: 5
                        padH: 3
                        marginRight: 0
                        glyphSize: 18

                        glyphYOffset: 0
                        textColor: Style.text2

                        opacityVal: weather.stale ? 0.45 : 1.0

                        glyph: weather.current ? weather.glyph(weather.current.code, weather.current.isDay) : "\u{F013}"
                        tailText: weather.current ? Math.round(weather.current.temp) + "°" : ""
                        tailSize: 14
                        tailGap: 2
                        onClicked: qsRoot.panelToggle("weather")
                    }

                    WifiModule {
                        id: wifiModule
                        qsRoot: rootRef
                    }

                    WiredModule {
                        id: wiredModule
                        qsRoot: rootRef
                        wifiModule: wifiModuleRef
                    }

                    NoNetModule {
                        id: noNetModule
                        qsRoot: rootRef
                        wifiModule: wifiModuleRef
                        wiredModule: wiredModuleRef
                    }

                    NetSpeedModule {
                        id: netSpeedModule
                        qsRoot: rootRef
                    }

                    Module {
                        id: btModule
                        shown: btModule.btPresent
                        bgColor: "transparent"
                        radius: 5
                        padLeft: 1
                        padRight: 3
                        marginLeft: 1
                        marginRight: 0
                        contentYOffset: 1

                        contentWidth: btText.implicitWidth + (btNameText.visible ? 4 + btNameText.width : 0)

                        readonly property bool btPresent: Style.btPresent
                        readonly property bool btOn: Style.btOn
                        readonly property var btConn: Style.connectedBtDevice()

                        Text {
                            id: btText

                            x: 0
                            anchors.verticalCenter: parent.verticalCenter

                            text: btModule.btOn ? "\uF293" : "\u{F00B2}"
                            color: btModule.btOn ? Style.text2 : Style.text3
                            font.family: Style.nerd
                            font.pixelSize: 18
                        }

                        Text {
                            id: btNameText

                            visible: qsRoot.showBtDevice && btModule.btConn !== null
                            x: btText.x + btText.implicitWidth + 4
                            anchors.verticalCenter: parent.verticalCenter
                            text: btModule.btConn ? btModule.btConn.name : ""
                            textFormat: Text.PlainText
                            color: Style.text2
                            font.family: Style.cjk

                            font.pixelSize: 14
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, 140)
                        }

                        onClicked: Style.probePanelApp(["blueman-manager"])

                        onRightClicked: qsRoot.btToggle("right-click")
                    }

                    Module {
                        id: ppdModule
                        shown: qsRoot.showPpd
                        bgColor: "transparent"
                        radius: 5
                        padLeft: 3
                        padRight: 3
                        marginRight: 0
                        contentYOffset: 1
                        contentWidth: ppdText.implicitWidth

                        Text {
                            id: ppdText
                            anchors.centerIn: parent
                            color: Style.text2
                            font.family: Style.nerd
                            font.pixelSize: 16
                            text: {
                                if (PowerProfiles.profile === PowerProfile.Performance)
                                    return "\uF0E7";
                                if (PowerProfiles.profile === PowerProfile.PowerSaver)
                                    return "\uF06C";
                                return "\uF0E4";
                            }
                        }

                        onClicked: {
                            if (PowerProfiles.profile === PowerProfile.Performance)
                                PowerProfiles.profile = PowerProfile.Balanced;
                            else if (PowerProfiles.profile === PowerProfile.Balanced)
                                PowerProfiles.profile = PowerProfile.PowerSaver;
                            else if (PowerProfiles.hasPerformanceProfile)
                                PowerProfiles.profile = PowerProfile.Performance;
                            else
                                PowerProfiles.profile = PowerProfile.Balanced;
                        }
                    }

                    PrivacyModule {
                        id: privacyModule
                        qsRoot: rootRef
                        panel: panelRef
                    }

                    NotifyButton {
                        id: notifyButton
                        center: notifCenter

                        marginRight: 1

                        onClicked: notifCenter.togglePanel(screenRoot.screenKey)
                        onRightClicked: notifCenter.toggleDnd()
                    }

                    BarButton {

                        glyph: Style.systemDark ? "\u{F0594}" : "\u{F522}"

                        glyphSize: 17
                        padH: 2
                        marginRight: 2
                        glyphYOffset: 1
                        onClicked: Quickshell.execDetached(["bash", Style.configDir + "/scripts/theme-toggle.sh"])
                    }

                    BarButton {
                        id: wallpaperModule
                        shown: qsRoot.showWallpaper
                        glyph: "\u{F0E09}"
                        glyphSize: 18
                        padH: 2
                        marginRight: 2
                        glyphYOffset: 1
                        onClicked: qsRoot.panelToggle("wallpaper")
                    }

                    BarButton {
                        shown: qsRoot.showClips
                        glyph: "\u{F0147}"
                        glyphSize: 18
                        padH: 2
                        marginRight: 2
                        glyphYOffset: 1
                        onClicked: clipsToggle()
                    }

                    BarButton {
                        id: rebootButton
                        shown: qsRoot.showReboot && rebootNeeded.needs
                        glyph: "\uF2F1"
                        glyphSize: 18

                        padH: 2
                        marginRight: 2
                        glyphYOffset: 1

                        textColor: Style.accent
                        onClicked: qsRoot.notifyReboot("left-click")
                        onRightClicked: rebootNeeded.kick()
                    }

                    BarButton {
                        glyph: "\uF013"
                        glyphSize: 18
                        padH: 2
                        marginRight: 3
                        glyphYOffset: 1
                        onClicked: qsRoot.panelToggle("settings")
                    }

                    Module {
                        id: volModule
                        bgColor: "transparent"
                        radius: 5
                        padLeft: 1
                        padRight: 1
                        contentYOffset: 1
                        contentWidth: volIcon.implicitWidth

                        wheelEnabled: true
                        onWheelNotch: d => qsRoot.audioStep(d * 5, "wheel")

                        readonly property var sink: Pipewire.defaultAudioSink
                        readonly property var audio: (volModule.sink && volModule.sink.audio) ? volModule.sink.audio : null

                        Text {
                            id: volIcon
                            anchors.centerIn: parent
                            color: volModule.audio && volModule.audio.muted ? Style.text1 : Style.text2
                            font.family: Style.nerd
                            font.pixelSize: 18

                            readonly property bool btSink: {
                                const s = volModule.sink;
                                if (!s)
                                    return false;
                                if (String(s.name).indexOf("bluez_output") === 0)
                                    return true;
                                try {
                                    return s.properties["device.api"] === "bluez5";
                                } catch (e) {
                                    return false;
                                }
                            }
                            text: {
                                let icon = "";
                                if (!volModule.audio || volModule.audio.muted)
                                    icon = "\uF026";
                                else
                                    icon = volModule.audio.volume <= 0.34 ? "\uF027" : "\uF028";

                                return (btSink ? "\uF294" : "") + icon;
                            }
                        }

                        onClicked: Style.probePanelApp(["pavucontrol"])

                        onRightClicked: qsRoot.audioToggleMute("right-click")
                    }

                    VolumeSlider {
                        qsRoot: rootRef
                    }

                    BrightnessModule {
                        id: brightnessModule
                        qsRoot: rootRef
                        brightnessPopup: brightnessPopupRef

                        onProbeGaveUp: reason => qsRoot.brightnessProbeGaveUp(reason)

                        BrightnessPopup {
                            id: brightnessPopup
                            panel: panelRef
                            brightnessModule: brightnessModuleRef
                        }
                    }

                    BatteryModule {
                        id: batteryModule
                        qsRoot: rootRef
                    }

                    TrayModule {
                        id: trayModule
                        panel: panelRef
                    }

                    BarButton {
                        glyph: "\uf011"
                        glyphSize: 18
                        padH: 3
                        marginLeft: 5
                        marginRight: 1
                        glyphYOffset: 1
                        opacityVal: 0.8

                        onClicked: qsRoot.panelSet("powermenu", true)
                    }

                    KeyboardModule {
                        id: kbModule
                        qsRoot: rootRef
                    }

                    Module {
                        id: langModule
                        shown: qsRoot.showLanguage
                        bgColor: "transparent"

                        hoverTint: false
                        radius: 0
                        padLeft: 5

                        padRight: 1
                        marginRight: 0
                        contentYOffset: 1
                        contentWidth: langText.implicitWidth

                        readonly property string shortName: Compositor.layoutShort()

                        Text {
                            id: langText

                            x: (parent.width - width) / 2
                            y: (parent.height - height) / 2
                            text: langModule.shortName
                            color: Style.text2
                            font.family: Style.nerd
                            font.pixelSize: 16
                        }
                    }

                    PomodoroPopup {
                        id: pomodoroPopup
                        bar: panel
                        qsRoot: rootRef
                        moduleRef: pomodoroModuleRef
                    }

                    PomodoroModule {
                        id: pomodoroModuleRef
                        shown: qsRoot.showPomodoro
                        contentYOffset: 1
                        focusMin: qsRoot.pomodoroFocusMin
                        breakMin: qsRoot.pomodoroBreakMin
                        longMin: qsRoot.pomodoroLongMin
                        longEvery: qsRoot.pomodoroLongEvery
                        popup: pomodoroPopup
                    }

                    ClockModule {
                        id: clockModule
                        qsRoot: rootRef
                    }
                }
            }

            Loader {
                active: screenPanels.calendarByScreen[screenRoot.screenKey] === true
                onLoaded: item.open()
                sourceComponent: CalendarPopup {
                    qsRoot: rootRef
                    panel: panelRef
                    clockModule: clockModuleRef
                    onVisibleChanged: if (!visible)
                        screenPanels.setActive("calendar", screenRoot.screenKey, false)
                }
            }

            Loader {
                active: screenPanels.weatherPopupByScreen[screenRoot.screenKey] === true
                onLoaded: item.open()
                sourceComponent: WeatherPopup {
                    qsRoot: rootRef
                    panel: panelRef
                    weather: weatherRef
                    weatherModule: weatherModuleRef
                    onVisibleChanged: if (!visible)
                        screenPanels.setActive("weather", screenRoot.screenKey, false)
                }
            }

            Loader {
                active: screenPanels.wallpaperPopupByScreen[screenRoot.screenKey] === true
                onLoaded: item.open()
                sourceComponent: WallpaperPopup {
                    qsRoot: rootRef
                    panel: panelRef
                    wallpaperModule: wallpaperModuleRef
                    onVisibleChanged: if (!visible)
                        screenPanels.setActive("wallpaper", screenRoot.screenKey, false)
                }
            }

            Loader {
                active: screenPanels.launcherByScreen[screenRoot.screenKey] === true

                onLoaded: item.open()
                sourceComponent: AppLauncher {
                    bar: panel
                    emptyWs: qsRoot.launcherEmptyWs
                    onVisibleChanged: if (!visible)
                        screenPanels.setActive("launcher", screenRoot.screenKey, false)
                }
            }

            Loader {
                active: screenPanels.powerMenuByScreen[screenRoot.screenKey] === true
                onLoaded: item.open()
                sourceComponent: PowerMenu {
                    flow: powerFlow
                    bar: panel
                    onVisibleChanged: if (!visible)
                        screenPanels.setActive("powermenu", screenRoot.screenKey, false)
                }
            }

            Loader {
                active: screenPanels.clipsByScreen[screenRoot.screenKey] === true
                onLoaded: item.open()
                sourceComponent: ClipPicker {
                    bar: panel
                    qsRoot: rootRef
                    onVisibleChanged: if (!visible)
                        screenPanels.setActive("clips", screenRoot.screenKey, false)
                }
            }

            Loader {
                active: screenPanels.settingsByScreen[screenRoot.screenKey] === true
                onLoaded: item.open()
                sourceComponent: SettingsPanel {
                    bar: panel
                    qsRoot: rootRef
                    notifCenter: notifCenterRef
                    onVisibleChanged: if (!visible)
                        screenPanels.setActive("settings", screenRoot.screenKey, false)
                }
            }

            PolkitPrompt {
                id: polkitPrompt
                bar: panel
                agent: polkitAgent
                active: qsRoot.polkitHere(screenRoot.screenKey)
                sessionLocked: lockScreen.locked
            }

            PanelWindow {
                id: notifPopupWindow
                screen: screenRoot.modelData

                readonly property bool panelHere: notifCenter.panelOpen && notifCenter.panelScreen === screenRoot.screenKey

                readonly property real bellInset: Math.max(0, 1 + rightRow.width - (notifyButton.x + notifyButton.width))

                anchors.top: true
                anchors.right: true
                margins.right: panelHere ? 0 : bellInset

                exclusiveZone: 0

                focusable: panelHere
                color: "transparent"

                visible: (panelHere || notifCenter.openCount > 0) && (!notifCenter.popupSuppressed || notifCenter.criticalTracked || panelHere)

                WlrLayershell.layer: WlrLayer.Overlay
                implicitWidth: panelHere ? (Screen.width > 0 ? Screen.width : 1280) : 300
                implicitHeight: panelHere ? (Screen.height > 0 ? Screen.height : 800) : content.implicitHeight

                Item {
                    id: content
                    width: parent.width
                    height: parent.height
                    implicitHeight: notifPopupWindow.panelHere ? notifPopupWindow.implicitHeight : popupColumn.implicitHeight

                    SafeMouseArea {
                        anchors.fill: parent
                        visible: notifPopupWindow.panelHere
                        enabled: visible
                        onClicked: notifCenter.closePanel()
                    }

                    Column {
                        id: popupColumn
                        width: parent.width
                        visible: !notifPopupWindow.panelHere
                        spacing: 6

                        Repeater {
                            model: notifCenter.server.trackedNotifications
                            delegate: NotificationPopup {
                                notification: modelData
                                center: notifCenter

                                actionRouter: qsRoot.notificationActionRoute

                                visible: (notifCenter.popupSuppressed && notifCenter.criticalTracked) ? (!!modelData && modelData.urgency === 2) : index >= notifCenter.openCount - notifCenter.maxVisible
                            }
                        }
                    }

                    NotificationCenterPanel {
                        id: historyPanel
                        visible: notifPopupWindow.panelHere

                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.rightMargin: notifPopupWindow.bellInset
                        center: notifCenter

                        focus: notifPopupWindow.panelHere
                        Keys.onEscapePressed: notifCenter.closePanel()

                        Keys.onUpPressed: historyPanel.moveSel(-1)
                        Keys.onDownPressed: historyPanel.moveSel(1)

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_PageUp) {
                                historyPanel.moveSelPage(-1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_PageDown) {
                                historyPanel.moveSelPage(1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Home) {
                                historyPanel.moveSelEnd(false);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_End) {
                                historyPanel.moveSelEnd(true);
                                event.accepted = true;
                            }
                        }

                        Keys.onReturnPressed: historyPanel.activateSel()
                        Keys.onEnterPressed: historyPanel.activateSel()
                        Keys.onDeletePressed: historyPanel.removeSel()
                    }
                }
            }
        }
    }
}
