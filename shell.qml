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

    property bool showLunar: false

    property bool showWeather: false

    property bool showReboot: false
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

    property var calendarByScreen: ({})
    property var weatherPopupByScreen: ({})
    property var trayRowByScreen: ({})

    function focusedScreenName() {
        if (Style.compositor === "niri")
            return Style.niriFocusedOutput;
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
                return p ? (k + ": active=" + p.active + " shown=" + p.shown + " mapped=" + p.visible + " size=" + Math.round(p.width) + "x" + Math.round(p.height)) : (k + ": <失效>");
            })
        });
    }

    function panelForFocused(map) {
        return map[qsRoot.focusedScreenName()] || Object.values(map)[0] || null;
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
                for (const k of qsRoot.showFlags)
                    if (saved[k] !== undefined)
                        qsRoot[k] = saved[k] === true;
                if (saved.barHeight !== undefined)
                    Style.barHeight = Math.max(24, Math.min(48, saved.barHeight));
                if (saved.historyLimit !== undefined)
                    notifCenter.historyLimit = Math.max(5, Math.min(50, saved.historyLimit));
                if (saved.clipMaxEntries !== undefined)
                    qsRoot.clipMaxEntries = Math.max(10, Math.min(200, saved.clipMaxEntries));
                if (saved.idleLockMinutes !== undefined)
                    qsRoot.idleLockMinutes = Math.max(0, Math.min(60, saved.idleLockMinutes));
                if (saved.idleDpmsMinutes !== undefined)
                    qsRoot.idleDpmsMinutes = Math.max(0, Math.min(60, saved.idleDpmsMinutes));
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
        if (qsRoot.barSettingsLoaded && notifCenter.historyLoaded)
            notifCenter.applyHistoryLimit();
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
        console.log("[BT] " + how + " 切蓝牙 → " + (want ? "开" : "关") + "(走 " + via + ")");
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
            console.log("[VOL] " + how + " 切静音: 还没有默认输出, 空动作");
            return JSON.stringify({
                muted: null
            });
        }
        audio.muted = !audio.muted;
        console.log("[VOL] " + how + " 切静音 → " + (audio.muted ? "静音" : "取消静音"));
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

    function netToggle(how) {
        const r = Style.netToggleLink();
        console.log("[NET] " + how + " 断/接网络(兜底) → " + r);
        return r;
    }
    function netToggleWifi(how) {
        const r = Style.netToggleWifiLink();
        console.log("[NET] " + how + " 无线那格 → " + r);
        return r;
    }
    function netToggleWired(how) {
        const r = Style.netToggleWiredLink();
        console.log("[NET] " + how + " 有线那格 → " + r);
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
            console.log("[REBOOT] " + how + ": 现在不需要重启/重登, 不发通知");
            return;
        }

        const notice = qsRoot.rebootNotice(rebootNeeded.newerKernel.length, rebootNeeded.newerModules.length, rebootNeeded.staleLibs.length, rebootNeeded.noticeDetail);
        console.log("[REBOOT] " + how + " 通知: 内核 " + rebootNeeded.newerKernel.length + " / 模块 " + rebootNeeded.newerModules.length + " / 用户态库 " + rebootNeeded.staleLibs.length);

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
            return "已触发重查(sh 异步), 1 秒后看 reboot state";
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
            console.log("[POLKIT] agent 注册 " + (polkitAgent.isRegistered ? "成功" : "失败 —— 可能已被别的 agent 占用(hyprpolkitagent?)"));
        }

        function onFlowChanged() {
            qsRoot.polkitScreenKey = polkitAgent.flow ? qsRoot.focusedScreenName() : "";
            if (polkitAgent.flow)
                console.log("[POLKIT] 收到授权请求: " + String(polkitAgent.flow.message) + " / " + String(polkitAgent.flow.actionId));
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

    Binding {
        target: Style
        property: "fullscreenWatch"
        value: qsRoot.fullscreenDnd || qsRoot.fullscreenIdleInhibit
    }

    Variants {
        model: Quickshell.screens

        delegate: Item {
            id: screenRoot

            required property var modelData

            property string screenKey: ""

            Component.onCompleted: {
                screenRoot.screenKey = modelData ? String(modelData.name) : "";
                qsRoot.launcherByScreen[screenRoot.screenKey] = appLauncher;
                qsRoot.clipsByScreen[screenRoot.screenKey] = clipPicker;
                qsRoot.powerMenuByScreen[screenRoot.screenKey] = powerMenu;
                qsRoot.promptByScreen[screenRoot.screenKey] = polkitPrompt;
                qsRoot.settingsByScreen[screenRoot.screenKey] = settingsPanel;
                qsRoot.calendarByScreen[screenRoot.screenKey] = calendarPopup;
                qsRoot.weatherPopupByScreen[screenRoot.screenKey] = weatherPopup;
                qsRoot.trayRowByScreen[screenRoot.screenKey] = trayRow;
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
                    enabled: qsRoot.fullscreenIdleInhibit && Style.fullscreenActive
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
                        opacity: 0.85

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

                        property string pendingTitle: Style.activeTitle
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
                        onClicked: Style.closeWindow()
                    }

                    Module {
                        id: mprisModule
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

                    BarButton {
                        id: tempModule
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

                    Module {
                        id: wifiModule
                        shown: wifiModule.wifiPresent
                        bgColor: "transparent"
                        radius: 5
                        padLeft: 3
                        padRight: 0
                        marginRight: 5
                        contentYOffset: 1
                        contentWidth: wifiRow.implicitWidth

                        readonly property var wifi: Style.connectedWifi()

                        readonly property bool wifiPresent: Style.wifiDevice() !== null

                        Row {
                            id: wifiRow
                            anchors.centerIn: parent
                            spacing: 5

                            Canvas {
                                id: wifiCanvas

                                visible: wifiModule.wifi !== null
                                anchors.verticalCenter: parent.verticalCenter
                                width: 18
                                height: 18
                                antialiasing: true
                                contextType: "2d"

                                property color ink: Style.text2
                                onInkChanged: requestPaint()

                                property int tier: {
                                    if (!wifiModule.wifi)
                                        return 0;
                                    let s = Number(wifiModule.wifi.signalStrength) || 0;
                                    if (s < 1)
                                        s *= 100;
                                    return s >= 75 ? 3 : s >= 50 ? 2 : s >= 25 ? 1 : 0;
                                }

                                onVisibleChanged: requestPaint()
                                onTierChanged: requestPaint()
                                onPaint: {
                                    const ctx = getContext("2d");
                                    ctx.reset();
                                    ctx.strokeStyle = ink;
                                    ctx.fillStyle = ink;
                                    ctx.lineWidth = 2;
                                    const cx = 9, cy = 14.4;
                                    const a0 = -Math.PI * 3 / 4, a1 = -Math.PI / 4;

                                    ctx.beginPath();
                                    ctx.arc(cx, cy, 1.5, 0, Math.PI * 2);
                                    ctx.fill();
                                    const radii = [4.3, 7.9, 11.5];
                                    for (let i = 0; i < 3; i++) {
                                        ctx.globalAlpha = i < tier ? 1 : 0.35;
                                        ctx.beginPath();
                                        ctx.arc(cx, cy, radii[i], a0, a1);
                                        ctx.stroke();
                                    }
                                    ctx.globalAlpha = 1;
                                }
                            }

                            Text {
                                id: wifiOffGlyph
                                visible: wifiModule.wifi === null
                                color: Style.text3
                                font.family: Style.nerd
                                font.pixelSize: 18
                                text: "\u{F05AA}"
                            }

                            Text {
                                id: wifiNameText
                                visible: qsRoot.showNetIface && wifiModule.wifi !== null
                                anchors.verticalCenter: parent.verticalCenter
                                color: Style.text2
                                font.family: Style.nerd
                                font.pixelSize: 14
                                width: Math.min(implicitWidth, 160)
                                elide: Text.ElideRight
                                text: wifiModule.wifi ? wifiModule.wifi.name : ""
                            }
                        }

                        onClicked: Quickshell.execDetached(["nm-applet"])

                        onRightClicked: qsRoot.netToggleWifi("右键")
                    }

                    Module {
                        id: wiredModule

                        readonly property bool hasLink: {
                            const d = Style.wiredDevice();
                            return d ? !!d.hasLink : false;
                        }
                        shown: wiredModule.wiredPresent && (wiredModule.hasLink || !wifiModule.wifiPresent)
                        bgColor: "transparent"
                        radius: 5
                        padLeft: 0
                        padRight: 0
                        marginRight: 5
                        contentYOffset: 1
                        contentWidth: wiredRow.implicitWidth

                        readonly property var wired: Style.connectedWired()

                        readonly property bool wiredPresent: Style.wiredDevice() !== null

                        Row {
                            id: wiredRow
                            anchors.centerIn: parent
                            spacing: 5

                            Text {
                                id: wiredGlyph
                                color: wiredModule.wired ? Style.text2 : Style.text3
                                font.family: Style.nerd
                                font.pixelSize: 18
                                text: wiredModule.wired ? "\u{F0200}" : "\u{F0202}"
                            }

                            Text {
                                id: wiredNameText
                                visible: qsRoot.showNetIface && wiredModule.wired !== null
                                anchors.verticalCenter: parent.verticalCenter
                                color: Style.text2
                                font.family: Style.nerd
                                font.pixelSize: 14
                                text: wiredModule.wired ? wiredModule.wired.name : ""
                            }
                        }

                        onClicked: Quickshell.execDetached(["nm-applet"])

                        onRightClicked: qsRoot.netToggleWired("右键")
                    }

                    Module {
                        id: noNetModule
                        shown: !wifiModule.wifiPresent && !wiredModule.wiredPresent
                        bgColor: "transparent"
                        radius: 5
                        padLeft: 0
                        padRight: 0
                        marginRight: 5
                        contentYOffset: 1
                        contentWidth: noNetGlyph.implicitWidth

                        Text {
                            id: noNetGlyph
                            anchors.centerIn: parent
                            color: Style.text2
                            font.family: Style.nerd
                            font.pixelSize: 18

                            text: "\u{F092E}"
                        }

                        onClicked: Quickshell.execDetached(["nm-applet"])

                        onRightClicked: qsRoot.netToggle("右键")
                    }

                    Module {
                        id: netSpeedModule
                        shown: qsRoot.showNetSpeed && (netSpeedModule.wifi !== null || netSpeedModule.wired !== null)
                        bgColor: "transparent"
                        radius: 5
                        padLeft: 0
                        padRight: 4
                        contentYOffset: 1
                        contentWidth: netSpeedMetrics.advanceWidth

                        readonly property var wifi: Style.connectedWifi()
                        readonly property var wired: Style.connectedWired()
                        property real rxSpeed: 0
                        property real txSpeed: 0
                        property var lastBytes: null

                        function fmtSpeed(v) {
                            v = Math.max(0, v);
                            let n, u;
                            if (v >= 1073741824) {
                                n = v / 1073741824;
                                u = "G";
                            } else if (v >= 1048576) {
                                n = v / 1048576;
                                u = "M";
                            } else if (v >= 1024) {
                                n = v / 1024;
                                u = "K";
                            } else {
                                n = v;
                                u = "B";
                            }
                            n = Math.min(999, Math.round(n));
                            return ("00" + n).slice(-3) + u;
                        }

                        function refreshSpeed(text) {
                            let rx = 0, tx = 0, seen = 0;
                            for (const l of String(text).split("\n").slice(2)) {
                                const f = l.trim().split(/[:\s]+/);
                                if (f.length < 10 || f[0] === "" || f[0] === "lo")
                                    continue;
                                rx += +f[1] || 0;
                                tx += +f[9] || 0;
                                seen++;
                            }

                            if (seen === 0)
                                return;
                            const now = Date.now();
                            if (lastBytes) {
                                const dt = (now - lastBytes.t) / 1000;
                                if (dt > 0) {
                                    rxSpeed = Math.max(0, (rx - lastBytes.rx) / dt);
                                    txSpeed = Math.max(0, (tx - lastBytes.tx) / dt);
                                }
                            }
                            lastBytes = {
                                rx: rx,
                                tx: tx,
                                t: now
                            };
                        }

                        FileView {
                            id: netFile
                            path: "/proc/net/dev"
                            blockLoading: true
                            printErrors: false
                        }

                        Timer {
                            interval: 1000
                            repeat: true
                            running: true
                            triggeredOnStart: true
                            onTriggered: {
                                if (!qsRoot.showNetSpeed)
                                    return;

                                if (netSpeedModule.wifi === null && netSpeedModule.wired === null)
                                    return;
                                netFile.reload();
                                netSpeedModule.refreshSpeed(netFile.text());
                            }
                        }

                        TextMetrics {
                            id: netSpeedMetrics
                            font.family: Style.nerd
                            font.pixelSize: 14
                            text: "↓000B ↑000B"
                        }

                        Text {
                            id: netSpeedText
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: 1

                            width: netSpeedMetrics.advanceWidth
                            horizontalAlignment: Text.AlignRight
                            color: Style.text2
                            font.family: Style.nerd
                            font.pixelSize: 14
                            text: "↓" + netSpeedModule.fmtSpeed(netSpeedModule.rxSpeed) + " ↑" + netSpeedModule.fmtSpeed(netSpeedModule.txSpeed)
                        }

                        onClicked: Quickshell.execDetached(["nm-applet"])
                        onRightClicked: qsRoot.netToggle("右键")
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

                        onRightClicked: qsRoot.btToggle("右键")
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

                    Module {
                        id: privacyModule
                        shown: qsRoot.showPrivacy && (privacyModule.micActive || privacyModule.shareActive)
                        bgColor: "transparent"
                        radius: 0

                        padLeft: 3
                        padRight: 3
                        marginRight: 0
                        contentYOffset: 1
                        contentWidth: privacyRow.implicitWidth

                        property bool micActive: false
                        property bool shareActive: false

                        function refreshPrivacy() {
                            let mic = false, share = false;
                            const nodes = Style.modelValues(Pipewire.nodes);
                            for (const n of nodes) {
                                if (!n)
                                    continue;

                                const t = Number(n.type);
                                if ((t & 4) && (t & 1) && (t & 8))
                                    mic = true;
                                else if ((t & 4) && (t & 2))
                                    share = true;
                            }
                            privacyModule.micActive = mic;
                            privacyModule.shareActive = share;
                            if (Style.debug) {
                                console.log("[PRIVACY] nodes=" + nodes.length + " mic=" + mic + " share=" + share + " comp=" + Style.compositor + " title=" + JSON.stringify(Style.activeTitle));
                            }
                        }

                        Connections {
                            target: Pipewire.nodes

                            enabled: qsRoot.showPrivacy
                            function onValuesChanged() {
                                privacyModule.refreshPrivacy();
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
                                text: "\uF130"
                                color: Style.privacyRed
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
                        onClicked: qsRoot.notifyReboot("左键")
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
                                return icon + (btSink ? "\uF294" : "");
                            }
                        }

                        onClicked: Quickshell.execDetached(["pavucontrol"])

                        onRightClicked: qsRoot.audioToggleMute("右键")
                    }

                    VolumeSlider {}

                    Module {
                        id: batteryModule

                        shown: qsRoot.showBattery && batteryModule.bat !== null

                        bgColor: batteryModule.critical ? Style.danger : Style.bg
                        opacityVal: batteryModule.critical ? (batteryModule.blinkOn ? 1.0 : 0.35) : 1.0
                        radius: 5
                        padLeft: 6
                        padRight: 0
                        marginRight: 0
                        contentYOffset: 1
                        contentWidth: batRow.implicitWidth

                        readonly property var bat: Style.laptopBattery()
                        readonly property real level: batteryModule.bat ? batteryModule.bat.percentage : 0

                        readonly property string pctText: batteryModule.bat ? String(Math.round(batteryModule.bat.percentage * 100)) : ""

                        readonly property string tag: !batteryModule.bat ? "" : (batteryModule.bat.state === UPowerDeviceState.Charging ? "\uF0E7" : (!UPower.onBattery ? "\uF1E6" : ""))
                        readonly property bool critical: batteryModule.bat !== null && batteryModule.bat.percentage <= 0.15 && batteryModule.bat.state !== UPowerDeviceState.Charging && UPower.onBattery
                        property bool blinkOn: false

                        Timer {
                            interval: 500
                            repeat: true
                            running: batteryModule.critical
                            onTriggered: batteryModule.blinkOn = !batteryModule.blinkOn
                        }

                        Row {
                            id: batRow
                            spacing: 1
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                id: batBody
                                width: 34
                                height: 16
                                radius: 3
                                color: "transparent"
                                border.width: 1.5
                                border.color: batteryModule.critical ? Style.danger : Style.text2

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.max(0, Math.round((batBody.width - 4) * batteryModule.level))
                                    height: batBody.height - 5
                                    radius: 1
                                    color: batteryModule.critical ? Style.danger : Style.accent
                                    opacity: 0.45
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: batteryModule.pctText
                                    color: batteryModule.critical ? Style.text3 : Style.text1
                                    font.family: Style.nerd
                                    font.pixelSize: 11
                                }
                            }

                            Rectangle {
                                width: 2.5
                                height: 7
                                radius: 1
                                anchors.verticalCenter: parent.verticalCenter
                                color: batteryModule.critical ? Style.danger : Style.text2
                            }

                            Text {
                                visible: batteryModule.tag !== ""
                                text: batteryModule.tag
                                color: batteryModule.critical ? Style.danger : Style.text2
                                font.family: Style.nerd
                                font.pixelSize: 13
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    Item {
                        id: trayModule

                        readonly property int padLeft: 6
                        implicitHeight: Style.barContentHeight

                        implicitWidth: trayRow.implicitWidth + trayModule.padLeft + 5

                        Row {
                            id: trayRow
                            x: trayModule.padLeft

                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10

                            property string lastMenuId: ""

                            function openMenu(which) {
                                for (let i = 0; i < trayRow.children.length; i++) {
                                    const c = trayRow.children[i];
                                    if (!c || !c.modelData || !c.modelData.hasMenu)
                                        continue;
                                    if (which && String(c.modelData.id) !== String(which))
                                        continue;
                                    trayRow.lastMenuId = String(c.modelData.id);
                                    const pos = c.mapToItem(panel.contentItem, 0, 0);
                                    c.modelData.display(panel, Math.round(pos.x), Math.round(pos.y) + Style.barHeight);
                                    return true;
                                }
                                return false;
                            }

                            function openNextMenu() {
                                const cands = [];
                                for (let i = 0; i < trayRow.children.length; i++) {
                                    const c = trayRow.children[i];
                                    if (c && c.modelData && c.modelData.hasMenu)
                                        cands.push(c);
                                }
                                if (cands.length === 0)
                                    return false;
                                let idx = 0;
                                for (let i = 0; i < cands.length; i++)
                                    if (String(cands[i].modelData.id) === trayRow.lastMenuId)
                                        idx = (i + 1) % cands.length;
                                return trayRow.openMenu(cands[idx].modelData.id);
                            }

                            function listItems() {
                                const out = [];
                                for (let i = 0; i < trayRow.children.length; i++) {
                                    const c = trayRow.children[i];
                                    if (!c || !c.modelData)
                                        continue;
                                    out.push({
                                        id: String(c.modelData.id),
                                        hasMenu: !!c.modelData.hasMenu,
                                        title: String(c.modelData.title)
                                    });
                                }
                                return JSON.stringify(out);
                            }

                            Repeater {
                                model: SystemTray.items

                                delegate: Item {
                                    id: trayItem
                                    implicitWidth: 11
                                    implicitHeight: 18

                                    property int reloadTries: 0

                                    required property var modelData

                                    IconImage {
                                        id: trayImg
                                        anchors.centerIn: parent
                                        width: 18
                                        height: 18
                                        source: trayF.source

                                        onStatusChanged: {
                                            if (status === Image.Error && trayItem.reloadTries < 3) {
                                                reloadTimer.restart();
                                            } else if (status === Image.Ready) {
                                                trayItem.reloadTries = 0;
                                            }
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: trayF.source === "" || trayImg.status === Image.Error
                                        text: "●"
                                        color: Style.text3
                                        font.family: Style.cjk
                                        font.pixelSize: 10
                                    }

                                    FileIcon {
                                        id: trayF
                                        iconName: modelData.icon
                                        onIconNameChanged: trayItem.reloadTries = 0
                                    }

                                    Timer {
                                        id: reloadTimer
                                        interval: 800
                                        onTriggered: {
                                            if (trayItem.reloadTries >= 3)
                                                return;
                                            trayItem.reloadTries++;
                                            trayF.restart();
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: mouse => {
                                            if (mouse.button === Qt.RightButton && modelData.hasMenu) {
                                                const pos = trayItem.mapToItem(panel.contentItem, 0, 0);

                                                modelData.display(panel, Math.round(pos.x), Math.round(pos.y) + Style.barHeight);
                                            } else {
                                                modelData.activate();
                                            }
                                        }
                                    }
                                }
                            }
                        }
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

                    Module {
                        id: kbModule
                        shown: qsRoot.showKeyboard && (kbModule.num || kbModule.caps)
                        bgColor: "transparent"
                        radius: 0
                        padLeft: 3
                        padRight: 1
                        marginRight: 0
                        contentYOffset: 1
                        contentWidth: kbRow.implicitWidth

                        property bool num: false
                        property bool caps: false

                        Poller {
                            active: qsRoot.showKeyboard
                            interval: 3000
                            command: ["sh", "-c", "n=0; c=0; s=; for k in numlock capslock; do v=; " + "for f in /sys/class/leds/*::$k/brightness; do " + "[ -e \"$f\" ] || break; read -r v < \"$f\"; break; done; " + "[ -n \"$v\" ] && s=1; " + "case $k in numlock) n=${v:-0};; capslock) c=${v:-0};; esac; done; " + "if [ -n \"$s\" ]; then printf 'led %s %s\\n' \"$n\" \"$c\"; " + (Style.compositor === "niri" ? "else printf 'led 0 0\\n'; fi" : "else exec hyprctl devices -j; fi")]
                            onOutput: text => {
                                const t = String(text).trim();

                                if (t.indexOf("led ") === 0) {
                                    const p = t.split(/\s+/);
                                    kbModule.num = p[1] === "1";
                                    kbModule.caps = p[2] === "1";
                                    return;
                                }

                                try {
                                    const d = JSON.parse(t);
                                    let num = false, caps = false;
                                    for (const k of (d.keyboards || [])) {
                                        if (k.numLock === true)
                                            num = true;
                                        if (k.capsLock === true)
                                            caps = true;
                                    }
                                    kbModule.num = num;
                                    kbModule.caps = caps;
                                } catch (e) {}
                            }
                        }

                        Row {
                            id: kbRow

                            x: (parent.width - width) / 2
                            y: (parent.height - height) / 2
                            spacing: 3

                            Text {
                                visible: kbModule.num

                                text: "\u{F03A6}"
                                color: Style.text1
                                font.family: Style.nerd
                                font.pixelSize: 19

                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                visible: kbModule.caps

                                text: "\u{F0A9B}"
                                color: Style.text1
                                font.family: Style.nerd
                                font.pixelSize: 17
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    Module {
                        id: langModule
                        shown: qsRoot.showLanguage
                        bgColor: "transparent"
                        radius: 0
                        padLeft: 5

                        padRight: 1
                        marginRight: 0
                        contentYOffset: 1
                        contentWidth: langText.implicitWidth

                        readonly property string shortName: Style.layoutShort()

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

                    Module {
                        id: clockModule
                        bgColor: "transparent"
                        radius: 4
                        padLeft: 5
                        padRight: 5
                        marginRight: 5
                        contentYOffset: 1

                        readonly property int clockPx: 16

                        readonly property int clockGap: 6

                        contentWidth: clockModule.alt ? clockWdMetrics.advanceWidth + clockDayMetrics.advanceWidth + clockTimeMetrics.advanceWidth + 2 * clockModule.clockGap : clockText.implicitWidth

                        property bool alt: false

                        property string clockStr: Style.timeStr(qsRoot.showClockSeconds)

                        readonly property var altParts: clockModule.alt ? (function () {
                                const tick = clockModule.clockStr;
                                return I18n.dateParts(qsRoot.showClockSeconds);
                            })() : {
                            wd: "",
                            day: "",
                            time: ""
                        }

                        TextMetrics {
                            id: clockWdMetrics
                            font.family: Style.nerd
                            font.pixelSize: clockModule.clockPx
                            text: I18n.dateSampleParts(qsRoot.showClockSeconds).wd
                        }
                        TextMetrics {
                            id: clockDayMetrics
                            font.family: Style.nerd
                            font.pixelSize: clockModule.clockPx
                            text: I18n.dateSampleParts(qsRoot.showClockSeconds).day
                        }
                        TextMetrics {
                            id: clockTimeMetrics
                            font.family: Style.nerd
                            font.pixelSize: clockModule.clockPx

                            text: I18n.dateSampleParts(qsRoot.showClockSeconds).time
                        }

                        Text {
                            id: clockText
                            anchors.centerIn: parent
                            visible: !clockModule.alt
                            text: clockModule.clockStr
                            color: Style.text2
                            font.family: Style.nerd
                            font.pixelSize: clockModule.clockPx
                        }

                        Row {
                            id: clockAltRow
                            anchors.centerIn: parent
                            visible: clockModule.alt
                            spacing: clockModule.clockGap

                            Text {
                                id: clockAltWd
                                text: clockModule.altParts.wd
                                color: Style.text2
                                font.family: Style.nerd
                                font.pixelSize: clockModule.clockPx
                            }
                            Text {
                                text: clockModule.altParts.day
                                color: Style.text2
                                font.family: Style.nerd
                                font.pixelSize: clockModule.clockPx
                                anchors.baseline: clockAltWd.baseline
                            }
                            Text {
                                text: clockModule.altParts.time
                                color: Style.text2
                                font.family: Style.nerd
                                font.pixelSize: clockModule.clockPx
                                anchors.baseline: clockAltWd.baseline
                            }
                        }

                        Timer {
                            id: clockSecTick
                            interval: 1000
                            running: qsRoot.showClockSeconds
                            repeat: true
                            onTriggered: clockModule.clockStr = Style.timeStr(true)
                        }
                        Timer {
                            id: clockMinTick
                            interval: 60000
                            running: !qsRoot.showClockSeconds
                            repeat: true
                            triggeredOnStart: true
                            onTriggered: {
                                clockModule.clockStr = Style.timeStr(false);

                                const d = new Date();
                                clockMinTick.interval = 60000 - (d.getSeconds() * 1000 + d.getMilliseconds()) + 30;
                                clockMinTick.restart();
                            }
                        }

                        onClicked: calendarPopup.toggle()
                        onRightClicked: clockModule.alt = !clockModule.alt
                    }
                }
            }

            PopupWindow {
                id: calendarPopup

                visible: false
                color: "transparent"

                function open() {
                    const now = new Date();
                    calendarPopup.viewYear = now.getFullYear();
                    calendarPopup.viewMonth = now.getMonth();
                    calendarPopup.visible = true;
                }
                function close() {
                    calendarPopup.visible = false;
                }
                function toggle() {
                    calendarPopup.visible ? calendarPopup.close() : calendarPopup.open();
                }

                function shiftMonth(d) {
                    let m = calendarPopup.viewMonth + d;
                    let y = calendarPopup.viewYear;
                    while (m < 0) {
                        m += 12;
                        y--;
                    }
                    while (m > 11) {
                        m -= 12;
                        y++;
                    }
                    calendarPopup.viewMonth = m;
                    calendarPopup.viewYear = y;
                }

                implicitWidth: 350

                implicitHeight: calCol.implicitHeight + 20 + Style.barHeight + 2 - Style.barInset
                grabFocus: true

                property int viewYear: new Date().getFullYear()
                property int viewMonth: new Date().getMonth()

                property bool showLunar: qsRoot.showLunar

                readonly property real cellW: (calendarPopup.width - 20) / 7

                readonly property int gridRows: Math.ceil((calendarPopup.firstOffset() + calendarPopup.daysInMonth()) / 7)

                anchor.window: panel
                anchor.item: clockModule
                anchor.edges: Edges.Bottom
                anchor.gravity: Edges.Top

                function firstOffset() {
                    const d = new Date(calendarPopup.viewYear, calendarPopup.viewMonth, 1);
                    return (d.getDay() + 6) % 7;
                }

                function daysInMonth() {
                    return new Date(calendarPopup.viewYear, calendarPopup.viewMonth + 1, 0).getDate();
                }

                function cellDay(i) {
                    const day = i - calendarPopup.firstOffset() + 1;
                    if (day < 1 || day > calendarPopup.daysInMonth())
                        return 0;
                    return day;
                }

                function cellDate(i) {
                    const day = calendarPopup.cellDay(i);
                    if (day === 0)
                        return null;
                    return new Date(calendarPopup.viewYear, calendarPopup.viewMonth, day);
                }

                function isToday(day) {
                    const n = new Date();
                    return day === n.getDate() && calendarPopup.viewYear === n.getFullYear() && calendarPopup.viewMonth === n.getMonth();
                }

                function isWeekend(i) {
                    return (i % 7) >= 5;
                }

                Rectangle {
                    id: calRect
                    anchors.fill: parent

                    anchors.topMargin: Style.barHeight + 2 - Style.barInset
                    radius: 12
                    color: Style.card
                    border.width: 1
                    border.color: Style.border

                    focus: true
                    Keys.onEscapePressed: calendarPopup.close()

                    Keys.onLeftPressed: calendarPopup.shiftMonth(-1)
                    Keys.onRightPressed: calendarPopup.shiftMonth(1)

                    Column {
                        id: calCol
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 6

                        Item {
                            width: parent.width
                            height: 30

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "‹"
                                color: Style.text3
                                font.family: Style.cjk
                                font.pixelSize: 22

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: calendarPopup.shiftMonth(-1)
                                }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.verticalCenter: parent.verticalCenter
                                text: I18n.calendarTitle(calendarPopup.viewYear, calendarPopup.viewMonth)
                                color: Style.text1
                                font.family: Style.cjk
                                font.pixelSize: 19
                                font.weight: Font.Bold
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: "›"
                                color: Style.text3
                                font.family: Style.cjk
                                font.pixelSize: 22

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: calendarPopup.shiftMonth(1)
                                }
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: 0

                            Repeater {

                                model: I18n.weekdayHeaders
                                delegate: Text {
                                    width: calendarPopup.cellW
                                    height: 24
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    text: modelData
                                    color: Style.accent
                                    font.family: Style.cjk
                                    font.pixelSize: 16
                                }
                            }
                        }

                        Grid {
                            width: parent.width
                            columns: 7
                            spacing: 0

                            Repeater {

                                model: calendarPopup.gridRows * 7

                                delegate: Item {
                                    width: calendarPopup.cellW
                                    height: 48
                                    readonly property int dayNum: calendarPopup.cellDay(index)

                                    readonly property var mark: calendarPopup.showLunar ? I18n.dayMark(calendarPopup.cellDate(index)) : {
                                        text: "",
                                        kind: ""
                                    }

                                    Rectangle {
                                        visible: calendarPopup.isToday(parent.dayNum)
                                        width: 26
                                        height: 26
                                        radius: 12
                                        color: "transparent"
                                        border.width: 1.5
                                        border.color: Style.accent
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.verticalCenter: calDayText.verticalCenter
                                    }

                                    Text {
                                        id: calDayText
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.top: parent.top
                                        anchors.topMargin: 4
                                        text: parent.dayNum || ""
                                        visible: parent.dayNum !== 0
                                        color: calendarPopup.isToday(parent.dayNum) ? Style.accent : (calendarPopup.isWeekend(index) ? Style.text3 : Style.text2)
                                        font.family: Style.cjk
                                        font.pixelSize: 16
                                        font.weight: calendarPopup.isToday(parent.dayNum) ? Font.Bold : Font.Normal
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.top: calDayText.bottom
                                        anchors.topMargin: 1
                                        visible: text !== ""
                                        text: (calendarPopup.showLunar && parent.dayNum !== 0) ? parent.mark.text : ""
                                        color: parent.mark.kind === "lunar" ? Style.text3 : Style.accent
                                        font.family: Style.cjk
                                        font.pixelSize: 12
                                    }
                                }
                            }
                        }

                        Item {
                            id: almanacBlock
                            width: parent.width
                            readonly property var info: calendarPopup.showLunar ? I18n.almanacToday(new Date()) : null
                            visible: info !== null
                            height: info !== null ? almCol.implicitHeight : 0

                            Column {
                                id: almCol
                                width: parent.width
                                spacing: 5

                                Rectangle {
                                    width: parent.width
                                    height: 1
                                    color: Style.border
                                    opacity: 0.4
                                }

                                Item {
                                    width: parent.width
                                    height: 30

                                    Row {
                                        id: almMoon
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6

                                        Text {
                                            height: 30
                                            verticalAlignment: Text.AlignVCenter
                                            color: Style.accent
                                            font.family: Style.nerd
                                            font.pixelSize: 26
                                            text: almanacBlock.info ? almanacBlock.info.moonGlyph : ""
                                        }
                                        Text {
                                            height: 30
                                            verticalAlignment: Text.AlignVCenter
                                            color: Style.text3
                                            font.family: Style.cjk
                                            font.pixelSize: 12
                                            text: almanacBlock.info ? almanacBlock.info.moon : ""
                                        }
                                    }

                                    Row {
                                        id: almTail
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6

                                        Text {
                                            height: 30
                                            verticalAlignment: Text.AlignVCenter
                                            color: Style.text3
                                            font.family: Style.cjk
                                            font.pixelSize: 12
                                            text: almanacBlock.info ? almanacBlock.info.gzDay : ""
                                        }
                                        Text {
                                            height: 30
                                            verticalAlignment: Text.AlignVCenter
                                            color: Style.accent
                                            font.family: Style.cjk
                                            font.pixelSize: 12
                                            text: almanacBlock.info ? almanacBlock.info.term : ""
                                        }
                                    }

                                    Text {
                                        anchors.left: almMoon.right
                                        anchors.leftMargin: 12
                                        anchors.right: almTail.left
                                        anchors.rightMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                        color: Style.text2
                                        font.family: Style.cjk
                                        font.pixelSize: 12
                                        text: almanacBlock.info ? almanacBlock.info.lunar + " · " + almanacBlock.info.gzYear : ""
                                    }
                                }
                            }
                        }
                    }
                }
            }

            PopupWindow {
                id: weatherPopup

                visible: false
                function open() {
                    if (qsRoot.showWeather && weather.ready)
                        weatherPopup.visible = true;
                }
                function close() {
                    weatherPopup.visible = false;
                }
                function toggle() {
                    weatherPopup.visible ? weatherPopup.close() : weatherPopup.open();
                }

                Connections {
                    target: weather
                    function onReadyChanged() {
                        if (!weather.ready)
                            weatherPopup.close();
                    }
                }

                color: "transparent"

                implicitWidth: 244

                implicitHeight: wxCol.implicitHeight + 20 + Style.barHeight + 2 - Style.barInset
                grabFocus: true

                anchor.window: panel
                anchor.item: weatherModule
                anchor.edges: Edges.Bottom
                anchor.gravity: Edges.Top

                Rectangle {
                    id: wxCard
                    anchors.fill: parent

                    anchors.topMargin: Style.barHeight + 2 - Style.barInset
                    radius: 12
                    color: Style.card
                    border.width: 1
                    border.color: Style.border
                    focus: true
                    Keys.onEscapePressed: weatherPopup.close()

                    Column {
                        id: wxCol
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 6

                        Item {
                            width: parent.width

                            height: 40

                            Text {
                                id: wxNowGlyph
                                anchors.left: parent.left
                                anchors.top: parent.top
                                color: Style.accent
                                font.family: Style.nerd
                                font.pixelSize: 30
                                text: weather.current ? weather.glyph(weather.current.code, weather.current.isDay) : ""
                            }
                            Text {
                                id: wxNowTemp
                                anchors.left: wxNowGlyph.right
                                anchors.leftMargin: 8

                                anchors.verticalCenter: parent.verticalCenter
                                color: Style.text1
                                font.family: Style.nerd
                                font.pixelSize: 22
                                font.bold: true
                                text: weather.current ? Math.round(weather.current.temp) + "°" : ""
                            }
                            Text {
                                anchors.left: wxNowTemp.right
                                anchors.leftMargin: 8
                                anchors.right: parent.right
                                anchors.baseline: wxNowTemp.baseline
                                elide: Text.ElideRight
                                color: Style.text2
                                font.family: Style.cjk
                                font.pixelSize: 13

                                text: weather.current ? I18n.t("wx.c." + weather.wmoKey(weather.current.code)) : ""
                            }
                        }

                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            color: Style.text3
                            font.family: Style.cjk

                            font.pixelSize: 13
                            text: weather.current ? I18n.t("wx.feels") + " " + Math.round(weather.current.feels) + "°  " + I18n.t("wx.humidity") + " " + Math.round(weather.current.humidity) + "%  " + I18n.t("wx.wind") + " " + Math.round(weather.current.wind) + " km/h" : ""
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Style.border
                            opacity: 0.4
                        }

                        Repeater {
                            model: weather.daily

                            delegate: Item {
                                required property var modelData
                                required property int index
                                width: parent ? parent.width : 0
                                height: 24

                                Text {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 52
                                    elide: Text.ElideRight
                                    color: Style.text2
                                    font.family: Style.cjk
                                    font.pixelSize: 13
                                    text: index === 0 ? I18n.t("wx.today") : (index === 1 ? I18n.t("wx.tomorrow") : I18n.weekdayShort(weather.dayDate(modelData.date)))
                                }
                                Text {
                                    id: wxDayGlyph
                                    anchors.left: parent.left
                                    anchors.leftMargin: 56
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Style.text3
                                    font.family: Style.nerd
                                    font.pixelSize: 15
                                    text: weather.glyph(modelData.code, true)
                                }
                                Text {
                                    id: wxDayRange
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Style.text2
                                    font.family: Style.nerd
                                    font.pixelSize: 13
                                    text: Math.round(modelData.min) + " / " + Math.round(modelData.max) + "°"
                                }

                                Text {
                                    anchors.left: wxDayGlyph.right
                                    anchors.leftMargin: 8
                                    anchors.right: wxDayRange.left
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter

                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    color: Style.text3
                                    font.family: Style.cjk
                                    font.pixelSize: 12
                                    text: I18n.t("wx.c." + weather.wmoKey(modelData.code))
                                }
                            }
                        }
                    }
                }
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
