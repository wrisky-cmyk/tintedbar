import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import Quickshell.Services.SystemTray
import Quickshell.Services.Notifications
import Quickshell.Services.Polkit
import Quickshell.Wayland
import Quickshell.Wayland._IdleInhibitor
import Quickshell.Widgets
import "components"

ShellRoot {
    id: qsRoot

    readonly property alias rootRef: qsRoot
    readonly property alias weatherRef: weather
    readonly property alias notifCenterRef: notifCenter

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

    property bool showBattery: Style.laptopBattery() !== null
    property bool showNetIface: false
    property bool showBtDevice: false
    property int clipMaxEntries: 50
    property bool showNetSpeed: false
    property bool showClockSeconds: false
    property bool clock24: true

    property bool showLunar: false

    property bool showWeather: false

    property bool showReboot: false

    property bool showBrightness: false
    property int idleLockMinutes: 5
    property int idleDpmsMinutes: 10

    property bool idleInhibited: false

    property bool fullscreenDnd: true

    property bool fullscreenIdleInhibit: false

    property var launcherByScreen: ({})
    property var clipsByScreen: ({})
    property var powerMenuByScreen: ({})

    property var promptByScreen: ({})

    property var settingsByScreen: ({})

    property var brightnessByScreen: ({})

    property var calendarByScreen: ({})
    property var weatherPopupByScreen: ({})
    property var trayRowByScreen: ({})

    function focusedScreenName() {
        if (Style.compositor === "niri")
            return Compositor.niriFocusedOutput;
        try {
            return Hyprland.focusedMonitor ? String(Hyprland.focusedMonitor.name) : "";
        } catch (e) {
            return "";
        }
    }

    property string polkitScreenKey: ""

    function polkitHere(key) {
        if (qsRoot.polkitScreenKey !== "")
            return key === qsRoot.polkitScreenKey;

        return Quickshell.screens.length > 0 && key === String(Quickshell.screens[0].name);
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
        return map[qsRoot.focusedScreenName()] || Object.values(map)[0] || null;
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
            key: "fullscreenDnd",
            labelKey: "flag.fullscreenDnd",
            group: "notif"
        }
    ]

    readonly property var showFlags: barFlagList.map(f => f.key)

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (qsRoot.home + "/.local/state")) + "/quickshell"

    function saveBarSettings() {
        barSettingsSaveDebounce.restart();
    }

    Timer {
        id: barSettingsSaveDebounce
        interval: 200
        onTriggered: {
            if (barSettingsSave.running) {
                restart();
                return;
            }
            barSettingsSave.command = ["sh", "-c", Style.atomicWriteCmd(qsRoot.stateDir + "/bar-settings.json", JSON.stringify(qsRoot.barSettingsObj()))];
            barSettingsSave.running = true;
        }
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
        o.barHeight = Style.barHeight;
        o.historyLimit = notifCenter.historyLimit;
        o.clipMaxEntries = qsRoot.clipMaxEntries;
        o.idleLockMinutes = qsRoot.idleLockMinutes;
        o.idleDpmsMinutes = qsRoot.idleDpmsMinutes;
        o.idleInhibited = qsRoot.idleInhibited;
        o.dnd = notifCenter.dnd;
        o.lang = I18n.lang;
        o.paletteName = Style.paletteName;
        return o;
    }

    function setHistoryLimit(v) {
        v = Math.max(5, Math.min(50, Math.round(v / 5) * 5));
        if (v === notifCenter.historyLimit)
            return;
        notifCenter.historyLimit = v;

        notifCenter.applyHistoryLimit();
        qsRoot.saveBarSettings();
    }

    function setClipMaxEntries(v) {
        v = Math.max(10, Math.min(200, Math.round(v / 10) * 10));
        if (v === qsRoot.clipMaxEntries)
            return;
        qsRoot.clipMaxEntries = v;
        qsRoot.saveBarSettings();
    }

    function setBarHeight(v) {
        v = Math.max(24, Math.min(48, Math.round(v)));
        if (v === Style.barHeight)
            return;
        Style.barHeight = v;
        qsRoot.saveBarSettings();
    }

    function setIdleLockMinutes(v) {
        v = Math.max(0, Math.min(60, Math.round(v)));
        if (v === qsRoot.idleLockMinutes)
            return;
        qsRoot.idleLockMinutes = v;
        qsRoot.saveBarSettings();
    }

    function setIdleDpmsMinutes(v) {
        v = Math.max(0, Math.min(60, Math.round(v)));
        if (v === qsRoot.idleDpmsMinutes)
            return;
        qsRoot.idleDpmsMinutes = v;
        qsRoot.saveBarSettings();
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
        id: barSettingsSave
        running: false
    }

    Process {
        id: themeApply
        running: true
        command: ["sh", "-c", "exec " + Style.sq(Style.configDir + "/scripts/theme-apply.sh")]
        onExited: {
            if (qsRoot.themeApplyPending) {
                qsRoot.themeApplyPending = false;
                themeApply.running = true;
            }
        }
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

    Process {
        id: barSettingsLoad
        running: true
        command: ["sh", "-c", Style.readJsonCmd(qsRoot.stateDir + "/bar-settings.json", "{}")]
        stdout: StdioCollector {
            onStreamFinished: {
                let saved = {};
                try {
                    saved = JSON.parse(text);
                } catch (e) {}
                if (!saved || typeof saved !== "object" || Array.isArray(saved))
                    saved = {};

                const num = v => {
                    const n = Number(v);
                    return isFinite(n) ? n : null;
                };
                for (const k of qsRoot.showFlags)
                    if (saved[k] !== undefined)
                        qsRoot[k] = saved[k] === true;
                const bh = num(saved.barHeight);
                if (bh !== null)
                    Style.barHeight = Math.max(24, Math.min(48, bh));
                const hl = num(saved.historyLimit);
                if (hl !== null)
                    notifCenter.historyLimit = Math.max(5, Math.min(50, hl));
                const cm = num(saved.clipMaxEntries);
                if (cm !== null)
                    qsRoot.clipMaxEntries = Math.max(10, Math.min(200, cm));
                const il = num(saved.idleLockMinutes);
                if (il !== null)
                    qsRoot.idleLockMinutes = Math.max(0, Math.min(60, il));
                const idm = num(saved.idleDpmsMinutes);
                if (idm !== null)
                    qsRoot.idleDpmsMinutes = Math.max(0, Math.min(60, idm));
                if (saved.idleInhibited !== undefined)
                    qsRoot.idleInhibited = saved.idleInhibited === true;

                if (saved.dnd !== undefined)
                    notifCenter.dnd = saved.dnd === true;

                if (!qsRoot.showIdleInhibitor)
                    qsRoot.idleInhibited = false;
                if (saved.lang === "auto" || I18n.langCodes.indexOf(saved.lang) >= 0)
                    I18n.lang = saved.lang;

                if (saved.paletteName === "auto" || Style.paletteIds.indexOf(saved.paletteName) >= 0)
                    Style.paletteName = saved.paletteName;

                qsRoot.barSettingsLoaded = true;
                qsRoot.settleHistoryLimit();
            }
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

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            const l = qsRoot.panelForFocused(qsRoot.launcherByScreen);
            if (l) {
                l.visible ? l.close() : l.open();
            }
        }
        function open(): void {
            const l = qsRoot.panelForFocused(qsRoot.launcherByScreen);
            if (l) {
                l.open();
            }
        }
        function close(): void {
            const l = qsRoot.panelForFocused(qsRoot.launcherByScreen);
            if (l) {
                l.close();
            }
        }
    }

    IpcHandler {
        target: "clips"

        function toggle(): void {
            const l = qsRoot.panelForFocused(qsRoot.clipsByScreen);
            if (l) {
                l.visible ? l.close() : l.open();
            }
        }
        function open(): void {
            const l = qsRoot.panelForFocused(qsRoot.clipsByScreen);
            if (l) {
                l.open();
            }
        }
        function close(): void {
            const l = qsRoot.panelForFocused(qsRoot.clipsByScreen);
            if (l) {
                l.close();
            }
        }
    }

    IpcHandler {
        target: "powermenu"

        function toggle(): void {
            const l = qsRoot.panelForFocused(qsRoot.powerMenuByScreen);
            if (l) {
                l.visible ? l.close() : l.open();
            }
        }
        function open(): void {
            const l = qsRoot.panelForFocused(qsRoot.powerMenuByScreen);
            if (l) {
                l.open();
            }
        }
        function close(): void {
            const l = qsRoot.panelForFocused(qsRoot.powerMenuByScreen);
            if (l) {
                l.close();
            }
        }
    }

    IpcHandler {
        target: "settings"

        function toggle(): void {
            const l = qsRoot.panelForFocused(qsRoot.settingsByScreen);
            if (l) {
                l.visible ? l.close() : l.open();
            }
        }
        function open(): void {
            const l = qsRoot.panelForFocused(qsRoot.settingsByScreen);
            if (l) {
                l.open();
            }
        }
        function close(): void {
            const l = qsRoot.panelForFocused(qsRoot.settingsByScreen);
            if (l) {
                l.close();
            }
        }
    }

    IpcHandler {
        target: "calendar"

        function toggle(): void {
            const l = qsRoot.panelForFocused(qsRoot.calendarByScreen);
            if (l) {
                l.toggle();
            }
        }
        function open(): void {
            const l = qsRoot.panelForFocused(qsRoot.calendarByScreen);
            if (l) {
                l.open();
            }
        }
        function close(): void {
            const l = qsRoot.panelForFocused(qsRoot.calendarByScreen);
            if (l) {
                l.close();
            }
        }
    }

    IpcHandler {
        target: "weather"

        function toggle(): void {
            const l = qsRoot.panelForFocused(qsRoot.weatherPopupByScreen);
            if (l) {
                l.toggle();
            }
        }
        function close(): void {
            const l = qsRoot.panelForFocused(qsRoot.weatherPopupByScreen);
            if (l) {
                l.close();
            }
        }
    }

    IpcHandler {
        target: "tray"

        function menu(): string {
            const r = qsRoot.panelForFocused(qsRoot.trayRowByScreen);
            if (!r)
                return "no-tray";
            return r.openMenu("") ? "opened" : "no-menu";
        }

        function menuOf(id: string): string {
            const r = qsRoot.panelForFocused(qsRoot.trayRowByScreen);
            if (!r)
                return "no-tray";
            return r.openMenu(id) ? "opened" : "not-found";
        }

        function next(): string {
            const r = qsRoot.panelForFocused(qsRoot.trayRowByScreen);
            if (!r)
                return "no-tray";
            return r.openNextMenu() ? "opened" : "no-menu";
        }

        function list(): string {
            const r = qsRoot.panelForFocused(qsRoot.trayRowByScreen);
            return r ? r.listItems() : "[]";
        }
    }

    IpcHandler {
        target: "notify"

        function toggle(): void {
            notifCenter.togglePanel(qsRoot.focusedScreenName());
        }
        function close(): void {
            notifCenter.closePanel();
        }

        function clear(): void {
            notifCenter.clearAll();
        }

        function state(): string {
            return JSON.stringify({
                tracked: notifCenter.openCount,
                maxTracked: notifCenter.maxTracked,
                maxVisible: notifCenter.maxVisible,
                history: notifCenter.history.length,
                historyLimit: notifCenter.historyLimit,
                unread: notifCenter.hasUnread,
                dnd: notifCenter.dnd,
                panel: notifCenter.panelOpen
            });
        }
    }

    IpcHandler {
        target: "lock"

        function lock(): void {
            lockScreen.lockNow();
        }
        function toggle(): void {
            lockScreen.lockNow();
        }
    }

    IpcHandler {
        target: "wallpaper"

        function reload(): void {
            WallpaperMap.reload();
        }
        function status(): string {
            return WallpaperMap.summary();
        }
    }

    IpcHandler {
        target: "palette"

        function state(): string {
            return JSON.stringify({
                palette: Style.paletteName,
                accent: String(Style.accent),
                themeAccent: String(Style.themeAccent),
                themeName: Style.gtkThemeName
            });
        }
        function next(): string {
            qsRoot.cyclePalette();
            return Style.paletteName;
        }
        function set(name: string): string {
            qsRoot.setPaletteName(String(name));
            return Style.paletteName;
        }

        function colors(): string {
            return Style.paletteReport();
        }

        function scan(): string {
            return Style.paletteScanReport();
        }
    }

    function btToggle(how) {
        const want = !Style.btOn;
        const via = Style.btSetEnabled(want);
        console.log("[BT] " + how + " toggle bt → " + (want ? "on" : "off") + "(via " + via + ")");
        return JSON.stringify({
            enabled: want,
            via: via
        });
    }
    IpcHandler {
        target: "bt"

        function state(): string {
            return Style.btState();
        }

        function toggle(): string {
            return qsRoot.btToggle("ipc");
        }
    }

    function audioToggleMute(how) {
        const sink = Pipewire.defaultAudioSink;
        const audio = (sink && sink.audio) ? sink.audio : null;
        if (!audio) {
            console.log("[VOL] " + how + " toggle mute: no default output yet, no-op");
            return JSON.stringify({
                muted: null
            });
        }
        audio.muted = !audio.muted;
        console.log("[VOL] " + how + " toggle mute → " + (audio.muted ? "muted" : "unmuted"));
        return JSON.stringify({
            muted: audio.muted
        });
    }
    IpcHandler {
        target: "audio"

        function state(): string {
            const sink = Pipewire.defaultAudioSink;
            const audio = (sink && sink.audio) ? sink.audio : null;
            return JSON.stringify({
                sink: sink ? String(sink.name) : null,
                volume: audio ? Math.round(audio.volume * 100) : null,
                muted: audio ? audio.muted : null
            });
        }

        function mute(): string {
            return qsRoot.audioToggleMute("ipc");
        }
    }
    IpcHandler {
        target: "debug"

        function on(): string {
            Style.debug = true;
            Compositor.debug = true;
            return JSON.stringify({
                debug: true,
                compositor: true
            });
        }
        function off(): string {
            Style.debug = false;
            Compositor.debug = false;
            return JSON.stringify({
                debug: false,
                compositor: false
            });
        }
        function state(): string {
            return JSON.stringify({
                debug: Style.debug,
                compositor: Compositor.debug
            });
        }
    }
    IpcHandler {
        target: "brightness"

        function state(): string {
            return qsRoot.brightnessIpcState();
        }

        function set(p: int): string {
            const m = qsRoot.panelForFocused(qsRoot.brightnessByScreen);
            if (m)
                m.setPct(p, "ipc");
            return qsRoot.brightnessIpcState();
        }
        function step(d: int): string {
            const m = qsRoot.panelForFocused(qsRoot.brightnessByScreen);
            if (m)
                m.stepPct(d, "ipc");
            return qsRoot.brightnessIpcState();
        }

        function preview(on: int): string {
            const m = qsRoot.panelForFocused(qsRoot.brightnessByScreen);
            if (m) {
                m.preview = on !== 0;
                if (m.preview && m.pct < 0)
                    m.pct = 42;
                console.log("[BRIGHT] preview " + (m.preview ? "on" : "off"));
            }
            return qsRoot.brightnessIpcState();
        }
    }

    function netToggle(how) {
        const r = Style.netToggleLink();
        console.log("[NET] " + how + " net disconnect/reconnect(fallback) → " + r);
        return r;
    }
    function netToggleWifi(how) {
        const r = Style.netToggleWifiLink();
        console.log("[NET] " + how + " wifi cell → " + r);
        return r;
    }
    function netToggleWired(how) {
        const r = Style.netToggleWiredLink();
        console.log("[NET] " + how + " wired cell → " + r);
        return r;
    }
    IpcHandler {
        target: "net"

        function state(): string {
            return Style.netState();
        }

        function toggle(): string {
            return qsRoot.netToggle("ipc");
        }

        function wifi(): string {
            return qsRoot.netToggleWifi("ipc");
        }

        function wired(): string {
            return qsRoot.netToggleWired("ipc");
        }
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
        const shellCmd = "k=$(notify-send -a quickshell -u normal -i " + action.icon + " -h string:x-quickshell-reboot:1" + " -A " + action.id + "=\"$QS_RB_ACTION\" \"$QS_RB_TITLE\" \"$QS_RB_BODY\"); " + "[ \"$k\" = " + action.id + " ] && " + action.command + "; true";
        Quickshell.execDetached(["env", "QS_RB_TITLE=" + notice.title, "QS_RB_BODY=" + notice.body, "QS_RB_ACTION=" + action.label, "sh", "-c", shellCmd]);
    }
    IpcHandler {
        target: "reboot"

        function state(): string {
            return JSON.stringify({
                needs: rebootNeeded.needs,
                needsReboot: rebootNeeded.needsReboot,
                needsRelogin: rebootNeeded.needsRelogin,
                count: rebootNeeded.count,
                kernel: rebootNeeded.newerKernel.length,
                modules: rebootNeeded.newerModules.length,
                libs: rebootNeeded.staleLibs.length,
                running: rebootNeeded.running,
                btime: rebootNeeded.btime,
                seenKernel: rebootNeeded.seenKernel,
                seenModules: rebootNeeded.seenModules,
                compositorPid: rebootNeeded.compositorPid,
                reason: rebootNeeded.reason,
                detailKernel: rebootNeeded.detailKernel,
                detailModules: rebootNeeded.detailModules,
                detailLibs: rebootNeeded.detailLibs,
                intervalMs: rebootNeeded.intervalMs
            });
        }

        function check(): string {
            rebootNeeded.kick();
            return "recheck triggered (sh async), see reboot state in 1s";
        }

        function notify(): string {
            qsRoot.notifyReboot("ipc");
            return JSON.stringify({
                needs: rebootNeeded.needs,
                count: rebootNeeded.count
            });
        }

        function preview(kernel: int, modules: int, libs: int): string {
            const detail = {
                kernel: kernel > 0 ? ["vmlinuz", "Image"] : [],
                modules: modules > 0 ? ["nvidia", "vboxdrv", "zfs"] : [],
                libs: libs > 0 ? ["libnvidia-glcore.so", "libnvidia-eglcore.so", "libc.so"] : []
            };
            return JSON.stringify(Object.assign(qsRoot.rebootNotice(kernel, modules, libs, detail), {
                action: qsRoot.rebootAction(kernel, modules)
            }));
        }

        function previewCurrent(): string {
            return JSON.stringify(Object.assign(qsRoot.rebootNotice(rebootNeeded.newerKernel.length, rebootNeeded.newerModules.length, rebootNeeded.staleLibs.length, rebootNeeded.noticeDetail), {
                action: qsRoot.rebootAction(rebootNeeded.newerKernel.length, rebootNeeded.newerModules.length)
            }));
        }
    }

    IpcHandler {
        target: "polkit"

        function state(): string {
            return qsRoot.polkitState();
        }

        function cancel(): void {
            if (polkitAgent.flow)
                polkitAgent.flow.cancelAuthenticationRequest();
        }
    }

    LockScreen {
        id: lockScreen
        idleLockMinutes: qsRoot.idleLockMinutes
        idleDpmsMinutes: qsRoot.idleDpmsMinutes
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

    RebootNeeded {
        id: rebootNeeded
        enabled: qsRoot.showReboot
    }

    Variants {
        model: Quickshell.screens

        delegate: Item {
            id: screenRoot

            required property var modelData

            property string screenKey: ""

            readonly property alias panelRef: panel
            readonly property alias weatherModuleRef: weatherModule
            readonly property alias clockModuleRef: clockModule
            readonly property alias calendarPopupRef: calendarPopup
            readonly property alias brightnessModuleRef: brightnessModule
            readonly property alias brightnessPopupRef: brightnessPopup
            readonly property alias wifiModuleRef: wifiModule
            readonly property alias wiredModuleRef: wiredModule

            Component.onCompleted: {
                screenRoot.screenKey = modelData ? String(modelData.name) : "";
                qsRoot.launcherByScreen[screenRoot.screenKey] = appLauncher;
                qsRoot.clipsByScreen[screenRoot.screenKey] = clipPicker;
                qsRoot.powerMenuByScreen[screenRoot.screenKey] = powerMenu;
                qsRoot.brightnessByScreen[screenRoot.screenKey] = brightnessModule;
                qsRoot.promptByScreen[screenRoot.screenKey] = polkitPrompt;
                qsRoot.settingsByScreen[screenRoot.screenKey] = settingsPanel;
                qsRoot.calendarByScreen[screenRoot.screenKey] = calendarPopup;
                qsRoot.weatherPopupByScreen[screenRoot.screenKey] = weatherPopup;
                qsRoot.trayRowByScreen[screenRoot.screenKey] = trayModule.trayRowItem;
            }
            Component.onDestruction: {
                delete qsRoot.launcherByScreen[screenRoot.screenKey];
                delete qsRoot.clipsByScreen[screenRoot.screenKey];
                delete qsRoot.powerMenuByScreen[screenRoot.screenKey];
                delete qsRoot.promptByScreen[screenRoot.screenKey];
                delete qsRoot.settingsByScreen[screenRoot.screenKey];
                delete qsRoot.calendarByScreen[screenRoot.screenKey];
                delete qsRoot.weatherPopupByScreen[screenRoot.screenKey];
                delete qsRoot.trayRowByScreen[screenRoot.screenKey];
                delete qsRoot.brightnessByScreen[screenRoot.screenKey];
            }

            PanelWindow {
                id: panel
                screen: screenRoot.modelData

                implicitWidth: screen ? screen.width : 1920

                implicitHeight: Style.barHeight

                anchors.top: true
                anchors.left: true
                anchors.right: true

                exclusiveZone: Style.barHeight
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
                        onClicked: appLauncher.visible ? appLauncher.close() : appLauncher.open()
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
                            anchors.centerIn: parent
                            spacing: 4

                            Repeater {
                                model: 10
                                delegate: WorkspaceButton {
                                    wsId: index + 1
                                    outputName: screenRoot.screenKey
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
                        onClicked: Quickshell.execDetached([Style.terminal])
                    }

                    BarButton {
                        shown: qsRoot.showBrowser
                        glyph: "\uF269"
                        glyphSize: 20
                        padH: 2
                        marginRight: 2
                        glyphYOffset: 2

                        onClicked: Quickshell.execDetached(["bash", "-c", "id=$(xdg-settings get default-web-browser 2>/dev/null); " + "if [ -n \"$id\" ]; then exec " + Style.sq(Style.configDir + "/scripts/launch-desktop.sh") + " \"$id\"; else exec xdg-open about:blank; fi"])
                    }

                    BarButton {
                        shown: qsRoot.showFilemanager
                        glyph: "\uEA83"
                        glyphSize: 20

                        fontWeight: Font.Bold
                        padH: 2
                        marginRight: 10
                        glyphYOffset: 1

                        onClicked: Quickshell.execDetached(["xdg-open", Quickshell.env("HOME")])
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
                            titleDebounce.restart();
                        }

                        Timer {
                            id: titleDebounce
                            interval: 250
                            onTriggered: titleText.shownTitle = titleText.pendingTitle
                        }

                        text: titleText.shownTitle
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
                            command: ["sh", "-c", "df -P / | tail -1"]
                            onOutput: text => {
                                const parts = String(text).trim().split(/\s+/);
                                diskModule.pct = parseInt(parts[4]) || 0;
                            }
                        }

                        onClicked: Quickshell.execDetached([Style.terminal, "-e", "top"])
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

                        onClicked: Quickshell.execDetached([Style.terminal, "-e", "top"])
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

                        onClicked: Quickshell.execDetached([Style.terminal, "-e", "top"])
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
                        shown: qsRoot.showWeather && weather.ready
                        bgColor: "transparent"
                        rad: 5
                        padH: 3
                        marginRight: 0
                        glyphSize: 18

                        glyphYOffset: 0
                        textColor: Style.text2

                        opacityVal: weather.stale ? 0.45 : 1.0

                        glyph: weather.current ? weather.glyph(weather.current.code, weather.current.isDay) : ""
                        tailText: weather.current ? Math.round(weather.current.temp) + "°" : ""
                        tailSize: 14
                        tailGap: 2
                        onClicked: weatherPopup.toggle()
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
                            color: Style.text2
                            font.family: Style.cjk

                            font.pixelSize: 14
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, 140)
                        }

                        onClicked: Quickshell.execDetached(["blueman-manager"])

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

                        onClicked: notifCenter.togglePanel(screenRoot.modelData.name)
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
                        shown: qsRoot.showClips
                        glyph: "\u{F0147}"
                        glyphSize: 18
                        padH: 2
                        marginRight: 2
                        glyphYOffset: 1
                        onClicked: clipPicker.visible ? clipPicker.close() : clipPicker.open()
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
                        onClicked: settingsPanel.toggle()
                    }

                    Module {
                        id: volModule
                        bgColor: "transparent"
                        radius: 5
                        padLeft: 1
                        padRight: 1
                        contentYOffset: 1
                        contentWidth: volIcon.implicitWidth

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

                        onClicked: Quickshell.execDetached(["pavucontrol"])

                        onRightClicked: qsRoot.audioToggleMute("right-click")
                    }

                    VolumeSlider {
                        qsRoot: rootRef
                    }

                    BrightnessModule {
                        id: brightnessModule
                        qsRoot: rootRef
                        brightnessPopup: brightnessPopupRef

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

                        onClicked: powerMenu.open()
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

                    ClockModule {
                        id: clockModule
                        qsRoot: rootRef
                        calendarPopup: calendarPopupRef
                    }
                }
            }

            CalendarPopup {
                id: calendarPopup
                qsRoot: rootRef
                panel: panelRef
                clockModule: clockModuleRef
            }

            WeatherPopup {
                id: weatherPopup
                qsRoot: rootRef
                panel: panelRef
                weather: weatherRef
                weatherModule: weatherModuleRef
            }

            AppLauncher {
                id: appLauncher
                bar: panel
            }

            PowerMenu {
                id: powerMenu
                bar: panel
            }

            ClipPicker {
                id: clipPicker
                bar: panel
            }

            SettingsPanel {
                id: settingsPanel
                bar: panel
                qsRoot: rootRef
                notifCenter: notifCenterRef
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

                anchors.top: true
                anchors.right: true
                margins.right: Math.max(0, 1 + rightRow.width - (notifyButton.x + notifyButton.width))

                exclusiveZone: 0

                focusable: panelHere
                color: "transparent"

                visible: (panelHere || notifCenter.openCount > 0) && !notifCenter.popupSuppressed

                WlrLayershell.layer: WlrLayer.Overlay
                implicitWidth: panelHere ? historyPanel.implicitWidth : 300
                implicitHeight: content.implicitHeight

                Item {
                    id: content
                    width: parent.width
                    implicitWidth: notifPopupWindow.implicitWidth
                    implicitHeight: notifPopupWindow.panelHere ? historyPanel.implicitHeight : popupColumn.implicitHeight

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

                                visible: index >= notifCenter.openCount - notifCenter.maxVisible
                            }
                        }
                    }

                    NotificationCenterPanel {
                        id: historyPanel
                        visible: notifPopupWindow.panelHere
                        center: notifCenter

                        focus: notifPopupWindow.panelHere
                        Keys.onEscapePressed: notifCenter.closePanel()

                        Keys.onUpPressed: historyPanel.moveSel(-1)
                        Keys.onDownPressed: historyPanel.moveSel(1)

                        Keys.onReturnPressed: historyPanel.activateSel()
                        Keys.onEnterPressed: historyPanel.activateSel()
                        Keys.onDeletePressed: historyPanel.removeSel()
                    }
                }
            }
        }
    }
}
