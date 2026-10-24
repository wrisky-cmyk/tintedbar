pragma Singleton

import QtQuick
import QtQml
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Notifications
import Quickshell.Services.UPower

Item {
    id: root

    readonly property string cjkFont: "Noto Sans CJK SC"
    readonly property string nerdFont: "JetBrainsMono Nerd Font"

    readonly property var fontFamilies: Qt.fontFamilies()
    function fontLoaded(name) {
        return name !== "" && root.fontFamilies.indexOf(name) >= 0;
    }
    readonly property bool cjkFontOk: root.fontLoaded(root.cjkFont)
    readonly property bool nerdFontOk: root.fontLoaded(root.nerdFont)

    readonly property string cjk: root.cjkFontOk ? root.cjkFont : ""
    readonly property string nerd: root.nerdFontOk ? root.nerdFont : ""

    property bool systemDark: true
    property string iconTheme: ""
    property string rawScheme: ""
    property int preferDarkGtk4: -1
    property int preferDarkGtk3: -1

    Process {
        id: schemeInit
        running: true
        command: ["sh", "-c", "gsettings get org.gnome.desktop.interface color-scheme; " + "gsettings get org.gnome.desktop.interface icon-theme; " + "gsettings get org.gnome.desktop.interface gtk-theme"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = String(text).split("\n");
                root.applyColorScheme(lines[0] || "");
                root.applyIconTheme(lines[1] || "");
                root.applyGtkThemeName(lines[2] || "");
            }
        }
    }

    Process {
        id: schemeMonitor
        running: true
        command: ["gsettings", "monitor", "org.gnome.desktop.interface"]
        stdout: SplitParser {
            onRead: line => root.handleInterfaceChange(line)
        }
        onExited: schemeMonitorRetry.restart()
    }
    Timer {
        id: schemeMonitorRetry
        interval: 2000
        onTriggered: if (!schemeMonitor.running)
            schemeMonitor.running = true
    }

    FileView {
        path: root.home + "/.config/gtk-4.0/settings.ini"
        preload: true
        printErrors: false
        watchChanges: true
        onLoaded: {
            root.preferDarkGtk4 = root.parsePreferDark(text());
            root.syncDark();
        }
        onFileChanged: reload()
    }
    FileView {
        path: root.home + "/.config/gtk-3.0/settings.ini"
        preload: true
        printErrors: false
        watchChanges: true
        onLoaded: {
            root.preferDarkGtk3 = root.parsePreferDark(text());
            root.syncDark();
        }
        onFileChanged: reload()
    }

    signal colorSchemeChanged

    signal colorSchemeValueChanged

    signal gtkThemeChanged

    function parsePreferDark(t) {
        const re = /^[ \t]*gtk-application-prefer-dark-theme[ \t]*=[ \t]*(\S+)/gm;
        const s = String(t);
        let m = null;
        let last = null;
        while ((m = re.exec(s)) !== null)
            last = m;
        if (!last)
            return -1;
        const v = last[1].toLowerCase();
        return (v === "1" || v === "true" || v === "yes" || v === "on") ? 1 : 0;
    }

    function syncDark() {
        let dark;

        if (root.preferDarkGtk4 >= 0)
            dark = root.preferDarkGtk4 === 1;
        else if (root.preferDarkGtk3 >= 0)
            dark = root.preferDarkGtk3 === 1;
        else {
            const s = root.rawScheme;
            if (s.indexOf("prefer-light") >= 0)
                dark = false;
            else
                dark = true;
        }
        if (dark === root.systemDark)
            return;
        root.systemDark = dark;
        root.colorSchemeChanged();
    }

    function applyColorScheme(v) {
        const before = root.rawScheme;
        root.rawScheme = String(v).trim();
        root.syncDark();

        if (before !== "" && root.rawScheme !== before)
            root.colorSchemeValueChanged();
    }

    function applyIconTheme(raw) {
        const it = String(raw).trim().replace(/^'|'$/g, "");
        if (it === "" || it === root.iconTheme)
            return;
        const first = root.iconTheme === "";
        root.iconTheme = it;
        if (!first) {
            IconProbe.iconCache = {};
            IconProbe._iconProbeGen++;
            IconProbe.iconProbesFinished();
        }
    }

    function applyGtkThemeName(raw) {
        const th = String(raw).trim().replace(/^'|'$/g, "");
        if (th === root.gtkThemeName)
            return false;
        root.gtkThemeName = th;
        root.reloadThemeCss();
        return true;
    }

    function handleInterfaceChange(line) {
        const t = String(line);
        const i = t.indexOf(":");
        if (i < 0)
            return;
        const key = t.substring(0, i).trim();
        const val = t.substring(i + 1).trim();
        if (key === "color-scheme")
            root.applyColorScheme(val);
        else if (key === "icon-theme")
            root.applyIconTheme(val);
        else if (key === "gtk-theme") {
            if (root.applyGtkThemeName(val))
                root.gtkThemeChanged();
        }
    }

    readonly property string compositor: Compositor.name

    property string gtkThemeName: ""

    readonly property string themeCssText: cssUser.loaded ? cssUser.text() : (cssSys.loaded ? cssSys.text() : "")
    property string themeCssOut: ""
    readonly property var themeColors: root.parseDefineColors(root.themeCssOut)

    Process {
        id: cssResolve
        running: false
        command: ["bash", root.configDir + "/scripts/theme-css.sh", root.gtkThemeName]
        stdout: StdioCollector {
            onStreamFinished: root.themeCssOut = text
        }
        onExited: {
            if (root.cssResolvePending) {
                root.cssResolvePending = false;
                root.reloadThemeCss();
            }
        }
    }
    property bool cssResolvePending: false

    function reloadThemeCss() {
        if (root.gtkThemeName === "") {
            root.themeCssOut = "";
            return;
        }
        if (cssResolve.running) {
            root.cssResolvePending = true;
            return;
        }
        root.themeCssOut = "";
        cssResolve.running = true;
    }

    function parseDefineColors(raw) {
        const map = {};
        if (!raw)
            return map;
        for (const line of String(raw).split("\n")) {
            if (line === "")
                continue;
            const i = line.indexOf("=");
            if (i <= 0)
                continue;
            const v = root.normalizeCssColor(line.substring(i + 1).trim());
            if (v !== "")
                map[line.substring(0, i)] = v;
        }
        return map;
    }

    function normalizeCssColor(v) {
        const m = /^rgba?\(([^)]*)\)$/i.exec(v);
        if (!m)
            return v;
        const p = m[1].split(",").map(s => s.trim());
        if (p.length !== 3 && p.length !== 4)
            return "";
        const n = [];
        for (const s of p) {
            if (s === "")
                return "";
            const x = Number(s);
            if (!isFinite(x))
                return "";
            n.push(x);
        }
        for (let i = 0; i < 3; i++)
            if (n[i] < 0 || n[i] > 255)
                return "";
        let a = 255;
        if (n.length === 4) {
            if (n[3] < 0 || n[3] > 1)
                return "";
            a = Math.round(n[3] * 255);
        }
        const h = x => {
            const s = Math.round(x).toString(16);
            return s.length < 2 ? "0" + s : s;
        };
        const rgb = h(n[0]) + h(n[1]) + h(n[2]);
        return a >= 255 ? "#" + rgb : "#" + h(a) + rgb;
    }

    function themeColor(names) {
        for (const n of names) {
            const v = root.themeColors[n];
            if (v !== undefined && v !== "")
                return v;
        }
        return "";
    }

    function mixColor(base, over, t) {
        const a = Qt.color(base);
        const b = Qt.color(over);
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t);
    }
    function withAlpha(c, alpha) {
        const x = Qt.color(c);
        return Qt.rgba(x.r, x.g, x.b, alpha);
    }

    FileView {
        id: cssUser
        path: root.home + "/.local/share/themes/" + root.gtkThemeName + "/gtk-3.0/gtk-dark.css"
        preload: true
        printErrors: false
        watchChanges: true
        onFileChanged: {
            reload();
            root.reloadThemeCss();
        }
    }
    FileView {
        id: cssSys
        path: "/usr/share/themes/" + root.gtkThemeName + "/gtk-3.0/gtk-dark.css"
        preload: true
        printErrors: false
        watchChanges: true
        onFileChanged: {
            reload();
            root.reloadThemeCss();
        }
    }

    property string paletteName: "auto"
    readonly property bool paletteAuto: root.paletteName === "auto"
    readonly property var paletteAccents: ({
            "tinted": "#7ab1ea",
            "cyan": "#47b8e6",
            "sea": "#a2adbf",
            "green": "#8cb887",
            "khaki": "#bfab7b",
            "orange": "#d0a47e",
            "red": "#d4a09b",
            "pink": "#cca0b6",
            "violet": "#b4a6d2"
        })

    readonly property var paletteNeutrals: ({
            "bgSolid": "#0e1621",
            "card": "#17212b",
            "text1": "#ffffff",
            "text2": "#d3dce5",
            "text3": "#a8b7c6",
            "hover": "#22303f",
            "trough": "#293a4c",
            "border": "#56697e"
        })

    readonly property var paletteIds: ["tinted", "cyan", "sea", "green", "khaki", "orange", "red", "pink", "violet"]

    function themeNameFor(id) {
        if (id === "tinted")
            return "Tinted";
        return "Tinted-" + id.charAt(0).toUpperCase() + id.slice(1);
    }

    readonly property color themeAccent: root.themeColor(["theme_selected_bg_color"]) || "#7ab1ea"

    readonly property color bgSolid: root.paletteAuto ? (root.themeColor(["theme_bg_color"]) || root.paletteNeutrals.bgSolid) : root.paletteNeutrals.bgSolid
    readonly property color bg: root.withAlpha(root.bgSolid, 0.55)

    readonly property real bgLum: {
        const c = Qt.color(root.bgSolid);
        return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
    }
    readonly property bool barDark: root.bgLum < 0.5

    readonly property color hover: !root.paletteAuto ? root.paletteNeutrals.hover : ((root.barDark ? root.themeColor(["BLACK_500"]) : "") || root.mixColor(root.bgSolid, root.text1, 0.11))
    readonly property color border: !root.paletteAuto ? root.paletteNeutrals.border : ((root.barDark ? (root.themeColor(["SILVER_900"]) || root.themeColor(["borders"])) : "") || root.mixColor(root.bgSolid, root.text1, 0.36))
    readonly property color text1: root.paletteAuto ? (root.themeColor(["theme_fg_color", "theme_text_color"]) || root.paletteNeutrals.text1) : root.paletteNeutrals.text1
    readonly property color text2: root.paletteAuto ? ((root.barDark ? root.themeColor(["SILVER_300"]) : "") || root.mixColor(root.text1, root.bgSolid, 0.15)) : root.paletteNeutrals.text2
    readonly property color text3: root.paletteAuto ? ((root.barDark ? root.themeColor(["SILVER_500"]) : "") || root.mixColor(root.text1, root.bgSolid, 0.35)) : root.paletteNeutrals.text3
    readonly property color trough: root.paletteAuto ? ((root.barDark ? root.themeColor(["SLATE_500"]) : "") || root.mixColor(root.bgSolid, root.text1, 0.15)) : root.paletteNeutrals.trough
    readonly property color fill: root.text2

    readonly property color danger: "#d75a5a"
    readonly property color accent: root.paletteAuto ? root.themeAccent : (root.paletteAccents[root.paletteName] || root.paletteAccents.tinted)

    readonly property color card: root.paletteAuto ? (root.themeColor(["theme_base_color"]) || root.paletteNeutrals.card) : root.paletteNeutrals.card

    function paletteReport() {
        return JSON.stringify({
            theme: root.gtkThemeName,
            cssChars: root.themeCssText.length,
            defines: Object.keys(root.themeColors).length,
            palette: root.paletteName,
            bg: String(root.bg),
            bgSolid: String(root.bgSolid),
            card: String(root.card),
            text1: String(root.text1),
            text2: String(root.text2),
            text3: String(root.text3),
            hover: String(root.hover),
            trough: String(root.trough),
            border: String(root.border),
            accent: String(root.accent),
            themeAccent: String(root.themeAccent),
            danger: String(root.danger)
        });
    }

    property string paletteScanText: ""
    function paletteScanReport() {
        let list = [];
        try {
            list = JSON.parse(root.paletteScanText);
        } catch (e) {
            list = [];
        }
        if (list.length === 0)
            return "not scanned yet (retry shortly if just started; also shown when no themes installed)";
        const tableThemes = root.paletteIds.map(id => root.themeNameFor(id));
        const lines = list.map(e => {
            const i = tableThemes.indexOf(e.name);
            return e.name + "\t" + e.accent + (i >= 0 ? "\t= family " + root.paletteIds[i] : "\t(not in table)");
        });
        const missing = tableThemes.filter(n => !list.some(e => e.name === n));
        return "scanned " + list.length + " installed themes:\n" + lines.join("\n") + "\nin table but not installed: " + (missing.length ? missing.join(" ") : "(none)");
    }

    Process {
        id: paletteScan
        running: true
        command: ["sh", "-c", "grep -H -m1 '^@define-color theme_selected_bg_color' " + "$HOME/.local/share/themes/*/gtk-3.0/gtk-dark.css " + "/usr/share/themes/*/gtk-3.0/gtk-dark.css 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root.adoptPaletteScan(text)
        }
    }

    function adoptPaletteScan(raw) {
        const seen = {};
        const out = [];
        for (const line of String(raw).split("\n")) {
            if (line === "")
                continue;
            const i = line.lastIndexOf(":");
            if (i < 0)
                continue;
            const parts = line.substring(0, i).split("/");
            const name = parts[parts.length - 3];
            const m = /#[0-9a-fA-F]{6}/.exec(line.substring(i + 1));
            if (name === undefined || m === null || seen[name])
                continue;
            seen[name] = true;
            out.push({
                name: name,
                accent: m[0].toLowerCase()
            });
        }
        out.sort((a, b) => a.name < b.name ? -1 : (a.name > b.name ? 1 : 0));
        root.paletteScanText = JSON.stringify(out);
    }

    property int barHeight: 38

    readonly property int barInset: Math.max(3, Math.round(barHeight / 10))
    readonly property int barContentHeight: barHeight - barInset * 2

    readonly property color privacyRed: "#f53c3c"
    readonly property color privacyOrange: "#ff9a3c"

    readonly property color notifText: root.text1

    readonly property color lockText: "#ffffff"
    readonly property color lockText2: "#c9d3dd"

    readonly property color notifBorderLow: root.themeColor(["success_color"]) || "#6fd061"
    readonly property color notifBorderNormal: root.accent
    readonly property color notifBorderHigh: root.themeColor(["error_color"]) || "#ea8a8a"

    readonly property color notifBgLow: root.withAlpha(root.card, 0.733)
    readonly property color notifBgNormal: root.withAlpha(root.card, 0.8)
    readonly property color notifBgHigh: root.withAlpha(root.card, 0.867)

    function notifBorder(u) {
        if (u === NotificationUrgency.Low)
            return root.notifBorderLow;
        if (u === NotificationUrgency.Critical)
            return root.notifBorderHigh;
        return root.notifBorderNormal;
    }

    function notifBg(u) {
        if (u === NotificationUrgency.Low)
            return root.notifBgLow;
        if (u === NotificationUrgency.Critical)
            return root.notifBgHigh;
        return root.notifBgNormal;
    }

    readonly property string terminal: Quickshell.env("TERMINAL") || "alacritty"

    readonly property string version: "26.10.24"

    readonly property string fingerprintCmd: "find shell.qml components scripts icons -type f ! -name '.*' ! -name '*~' ! -name '*.swp' -print0 | LC_ALL=C sort -z | xargs -0 sha256sum | sha256sum | cut -c1-8"
    property string packedVersion: ""
    property string packedFingerprint: ""
    property string packedPackaging: ""
    property string packedQuickshell: ""
    property string localFingerprint: ""
    readonly property bool packedCopy: packedFingerprint !== ""

    readonly property bool modified: packedCopy && localFingerprint !== packedFingerprint

    Process {
        id: manifestRead
        running: true
        command: ["sh", "-c", root.readJsonCmd(root.configDir + "/manifest.json", "{}")]
        stdout: StdioCollector {
            onStreamFinished: {
                let o = {};
                try {
                    o = JSON.parse(String(text) || "{}");
                } catch (e) {
                    console.log("[QS] manifest.json is not valid JSON, skip fingerprint check: " + e);
                    return;
                }
                root.packedVersion = String(o.version || "");
                root.packedFingerprint = String(o.fingerprint || "");
                root.packedPackaging = String(o.packaging || "");
                root.packedQuickshell = String(o.quickshell || "");
                if (root.packedFingerprint !== "")
                    fingerprintCalc.running = true;
                else
                    console.log("[QS] no manifest.json (dev tree), version line reports version only");
            }
        }
    }

    Process {
        id: fingerprintCalc
        command: ["sh", "-c", "cd " + root.sq(root.configDir) + " && " + root.fingerprintCmd]
        stdout: StdioCollector {
            onStreamFinished: {
                root.localFingerprint = String(text).trim();
                if (root.modified)
                    console.log("[QS] config content differs from release: expected " + root.packedFingerprint + ", got " + root.localFingerprint + " (packaging=" + root.packedPackaging + ")");
                else
                    console.log("[QS] config fingerprint " + root.localFingerprint + " (matches manifest)");
            }
        }
    }

    readonly property bool debug: Quickshell.env("QS_DEBUG") === "1"

    readonly property string home: Quickshell.env("HOME") || ""

    readonly property string configDir: Quickshell.shellDir

    function modelValues(model) {
        return Compositor.modelValues(model);
    }

    property var desktopEntryCache: ({})

    function appForClass(cls) {
        if (!cls)
            return null;
        const c = String(cls);
        const key = c.toLowerCase();
        if (key in root.desktopEntryCache)
            return root.desktopEntryCache[key];
        const e = root.lookupDesktopEntry(c);
        root.desktopEntryCache[key] = e;
        return e;
    }

    function lookupDesktopEntry(c) {
        const candidates = [c, c + ".desktop", c.toLowerCase(), c.toLowerCase() + ".desktop"];
        for (const id of candidates) {
            const e = DesktopEntries.byId(id);
            if (e && e.icon)
                return e;
        }
        const lc = c.toLowerCase();
        for (const app of root.modelValues(DesktopEntries.applications)) {
            if (app && app.startupClass && String(app.startupClass).toLowerCase() === lc && app.icon)
                return app;
        }
        const h = DesktopEntries.heuristicLookup(c);
        if (h && h.icon)
            return h;
        return null;
    }

    Component.onCompleted: {
        console.log("[QS] config version " + root.version);
        if (!root.cjkFontOk)
            console.warn("[FONT] font not found \"" + root.cjkFont + "\", falling back to default");
        if (!root.nerdFontOk)
            console.warn("[FONT] font not found \"" + root.nerdFont + "\", falling back to default (nerd icon glyphs may be missing)");
        DesktopEntries.applicationsChanged.connect(() => {
            root.desktopEntryCache = {};
        });
        root.btSync();
    }

    function appIconNames(cls) {
        if (!cls)
            return [];
        const out = [];
        const c = String(cls);
        const lc = c.toLowerCase();
        if (lc !== c && out.indexOf(lc) < 0)
            out.push(lc);
        if (out.indexOf(c) < 0)
            out.push(c);
        const app = root.appForClass(cls);
        if (app && app.icon && out.indexOf(String(app.icon)) < 0)
            out.push(String(app.icon));
        return out;
    }

    readonly property var titleIconRules: [[/^btop/i, "btop"], [/^htop/i, "htop"], [/^yazi/i, "yazi"], [/^cmus/i, "cmus"], [/^ranger/i, "ranger"], [/^nvim/i, "nvim"], [/helix/i, "helix"], [/^micro/i, "micro"]]
    function titleIcon(title) {
        const t = String(title || "");
        for (const r of root.titleIconRules)
            if (r[0].test(t))
                return r[1];
        return "";
    }

    function sq(s) {
        return Compositor.sq(s);
    }

    function atomicWriteCmd(path, json) {
        const p = String(path);
        const slash = p.lastIndexOf("/");

        const dir = slash < 0 ? "." : p.substring(0, slash);
        return "umask 077; mkdir -p " + sq(dir) + " && printf '%s' " + sq(json) + " > " + sq(path + ".tmp") + " && mv -f " + sq(path + ".tmp") + " " + sq(path);
    }

    function readJsonCmd(path, fallback) {
        return "[ -s " + sq(path) + " ] && cat " + sq(path) + " || printf '%s' " + sq(fallback);
    }

    function launchDesktop(id) {
        const s = String(id || "");
        if (s === "")
            return;
        Quickshell.execDetached(["bash", "-c", "exec " + root.sq(root.configDir + "/scripts/launch-desktop.sh") + " " + root.sq(s)]);
    }

    function glyphFor(cls, title) {
        const c = String(cls || "").toLowerCase();
        const t = String(title || "").toLowerCase();
        const byTitle = [[/btop/, "\u{F04C5}"], [/yazi/, "\u{F0645}"], [/ranger/, "\uEAF7"], [/cmus/, "\u{F0387}"]];
        for (const pair of byTitle)
            if (pair[0].test(t))
                return pair[1];
        const byClass = {
            "cc-switch": "\u{F04E6}",
            "firefox": "\uF269",
            "chrome": "\u{F02AF}",
            "chromium": "\u{F02AF}",
            "alacritty": "\uF489",
            "com.mitchellh.ghostty": "\uF120",
            "foot": "\uF120",
            "org.wezfurlong.wezterm": "\uF120",
            "code": "\u{F0A1E}",
            "codium": "\u{F0A1E}",
            "com.xunlei.download": "\uF019",
            "tdxcfv": "\uF201",
            "com.gitee.gmg137.neteasecloudmusicgtk4": "\u{F0F70}",
            "org.telegram.desktop": "\uF2C6",
            "wechat": "\uF1D7",
            "thunar": "\uEA83",
            "qq": "\uF1D6",
            "micro": "\uF044",
            "mpv": "\uF36E",
            "fcitx": "\uF11C",
            "wpsoffice": "\u{F03C6}",
            "baidunetdisk": "\uEAC2",
            "binance": "\uF10F",
            "clash-verge": "\u{F0582}",
            "localsend": "\u{F10DD}",
            "scrcpy": "\u{F04F7}",
            "blueman-manager": "\uF293",
            "org.pulseaudio.pavucontrol": "\u{F071F}"
        };
        for (const key in byClass)
            if (c.indexOf(key) >= 0)
                return byClass[key];
        return "\uF059";
    }

    function connectedWifi() {
        for (const d of root.modelValues(Networking.devices)) {
            if (!d || d.type !== DeviceType.Wifi || !d.connected)
                continue;
            for (const n of root.modelValues(d.networks)) {
                if (n && n.connected)
                    return n;
            }
        }
        return null;
    }

    function connectedWired() {
        for (const d of root.modelValues(Networking.devices)) {
            if (!d || d.type !== DeviceType.Wired)
                continue;
            if (d.connected)
                return d;
        }
        return null;
    }

    function wiredDevice() {
        for (const d of root.modelValues(Networking.devices)) {
            if (!d || d.type !== DeviceType.Wired || !d.nmManaged)
                continue;
            return d;
        }
        return null;
    }

    function wiredNetwork() {
        const d = root.wiredDevice();
        if (!d)
            return null;
        if (d.network)
            return d.network;
        for (const n of root.modelValues(d.networks))
            if (n)
                return n;
        return null;
    }

    function wifiDevice() {
        for (const d of root.modelValues(Networking.devices)) {
            if (!d || d.type !== DeviceType.Wifi || !d.nmManaged)
                continue;
            return d;
        }
        return null;
    }

    function netToggleWifiLink() {
        if (root.wifiDevice() === null)
            return JSON.stringify({
                acted: "nothing"
            });
        if (root.connectedWifi() !== null) {
            Networking.wifiEnabled = false;
            return JSON.stringify({
                acted: "wifi-radio",
                wifiEnabled: false,
                wifiHardware: Networking.wifiHardwareEnabled
            });
        }
        if (!Networking.wifiEnabled) {
            Networking.wifiEnabled = true;
            return JSON.stringify({
                acted: "wifi-radio",
                wifiEnabled: true,
                wifiHardware: Networking.wifiHardwareEnabled
            });
        }
        return JSON.stringify({
            acted: "nothing"
        });
    }

    function netToggleWiredLink() {
        const w = root.wiredDevice();
        if (w && w.connected) {
            w.disconnect();
            return JSON.stringify({
                acted: "wired-off",
                iface: String(w.name)
            });
        }

        const n = root.wiredNetwork();
        if (!n)
            return JSON.stringify({
                acted: "nothing"
            });
        n.connect();
        return JSON.stringify({
            acted: "wired-on",
            iface: w ? String(w.name) : null,
            net: String(n.name)
        });
    }

    function netToggleLink() {
        const w = root.wiredDevice();
        if (w && w.connected)
            return root.netToggleWiredLink();
        const hasWifi = root.wifiDevice() !== null;
        if (hasWifi && (root.connectedWifi() !== null || !Networking.wifiEnabled))
            return root.netToggleWifiLink();
        return JSON.stringify({
            acted: "nothing"
        });
    }

    function netState() {
        const w = root.connectedWifi();
        const e = root.connectedWired();
        const dev = root.wiredDevice();
        const wifiDev = root.wifiDevice();
        return JSON.stringify({
            wifiEnabled: Networking.wifiEnabled,
            wifiHardware: Networking.wifiHardwareEnabled,
            wiredIface: dev ? String(dev.name) : null,
            wifiIface: wifiDev ? String(wifiDev.name) : null,
            wifi: w ? String(w.name) : null,
            wired: e ? String(e.name) : null,
            devices: root.modelValues(Networking.devices).map(d => d ? {
                    name: String(d.name),
                    type: DeviceType.toString(d.type),
                    managed: d.nmManaged,
                    connected: d.connected,
                    nets: root.modelValues(d.networks).map(n => n ? String(n.name) : null),
                    hasLink: d.hasLink,
                    hasNetworks: d.networks !== undefined,
                    isWiredEnum: d.type === DeviceType.Wired
                } : null)
        });
    }

    function connectedBtDevice() {
        const a = root.btAdapter();
        if (!a)
            return null;
        for (const d of root.modelValues(a.devices))
            if (d && d.connected)
                return d;
        return null;
    }

    function laptopBattery() {
        for (const d of root.modelValues(UPower.devices)) {
            if (d && d.isLaptopBattery && d.isPresent)
                return d;
        }
        return null;
    }

    property int btTick: 0
    property bool btNotified: false
    property bool btMissedLogged: false
    property bool btProbeOn: false
    property bool btProbeKnown: false
    property bool btProbeLogged: false

    property bool btWantOpen: false
    property bool btWantOn: false
    property int btWantMs: 3000

    property int btRfkillFixes: 0
    property string btRfkillWhy: ""

    function btAdapter() {
        const a = Bluetooth.defaultAdapter;
        if (a)
            return a;
        for (const x of root.modelValues(Bluetooth.adapters))
            if (x)
                return x;
        return null;
    }

    readonly property bool btCacheTrusted: {
        const a = root.btAdapter();
        return !!a && a.enabled && a.state === BluetoothAdapterState.Enabled;
    }
    readonly property string btCacheDesc: {
        const a = root.btAdapter();
        if (!a)
            return "no adapter object";
        return "enabled=" + a.enabled + " state=" + BluetoothAdapterState.toString(a.state);
    }

    readonly property bool btPresent: root.btAdapter() !== null || root.btProbeKnown

    function bluetoothEnabled() {
        if (root.btWantOpen)
            return root.btWantOn;
        return root.btCacheTrusted ? true : root.btProbeOn;
    }

    readonly property bool btOn: root.btTick >= 0 && root.bluetoothEnabled()

    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: {
            root.btTick++;
            const now = root.bluetoothEnabled();
            if (now !== root.btNotified) {
                if (!root.btMissedLogged) {
                    root.btMissedLogged = true;
                    console.warn("[BT] icon state self-corrected: notification side thought " + root.btNotified + ", actual " + now + " —— backend missed change notification (§4.9); corrected to actual");
                }
                root.btNotified = now;
            }
        }
    }

    function btSync() {
        root.btNotified = root.bluetoothEnabled();
        root.btMissedLogged = false;
    }
    Connections {
        target: Bluetooth
        function onDefaultAdapterChanged() {
            root.btSync();
        }
    }
    Connections {
        target: root.btAdapter()

        function onEnabledChanged() {
            root.btProbeLogged = false;
            root.btSync();
        }
        function onStateChanged() {
            root.btProbeLogged = false;
            root.btSync();
        }
    }

    Poller {
        id: btPoller
        active: !root.btCacheTrusted

        interval: (root.btAdapter() !== null || root.btProbeKnown) ? 15000 : 60000
        command: ["busctl", "--system", "get-property", "org.bluez", root.btAdapter() ? String(root.btAdapter().dbusPath) : "/org/bluez/hci0", "org.bluez.Adapter1", "Powered"]
        onOutput: text => {
            const t = String(text).trim();

            const wantOpen = root.btWantOpen;
            root.btProbeKnown = t.indexOf("b ") === 0;
            root.btProbeOn = t.indexOf("true") >= 0;
            root.btSync();

            if (wantOpen && root.btProbeOn === root.btWantOn)
                root.btWantOpen = false;

            if (root.btProbeOn && root.btAdapter() !== null && !root.btProbeLogged && !wantOpen) {
                root.btProbeLogged = true;
                console.warn("[BT] backend cache untrustworthy (" + root.btCacheDesc + "), BlueZ actually Powered=true —— icon shows on (asked busctl directly, §4.9)");
            }
        }
    }

    Timer {
        interval: 400
        repeat: true
        running: root.btWantOpen
        onTriggered: btPoller.kick()
    }

    Timer {
        interval: root.btWantMs
        running: root.btWantOpen
        onTriggered: root.btWantOpen = false
    }

    Process {
        id: btUnblockProc
        command: ["rfkill", "unblock", "bluetooth"]
        onExited: code => {
            if (code !== 0)
                console.warn("[BT] rfkill unblock bluetooth exit code " + code + " —— block not lifted, still try one backend write (§4.9)");

            if (!root.btWantOn)
                return;
            const a = root.btAdapter();

            if (a && a.state !== BluetoothAdapterState.Blocked) {
                a.enabled = true;
                return;
            }
            console.log("[BT] backend cache still says " + root.btCacheDesc + " after unblock, this write goes to BlueZ directly via busctl (§4.9)");
            Quickshell.execDetached(["busctl", "--system", "set-property", "org.bluez", a ? String(a.dbusPath) : "/org/bluez/hci0", "org.bluez.Adapter1", "Powered", "b", "true"]);
        }
    }
    Timer {
        id: btFallbackTimer
        interval: 1500
        onTriggered: {
            if (!root.btWantOpen || !root.btWantOn)
                return;
            if (!root.btProbeKnown || root.btProbeOn)
                return;
            console.warn("[BT] still off 1.5s after backend on (BlueZ says Powered=false), bypass backend and write once via busctl" + " —— most likely backend cache still remembers rfkill block, cross-check with `rfkill list bluetooth` (§4.9)");
            Quickshell.execDetached(["busctl", "--system", "set-property", "org.bluez", root.btAdapter() ? String(root.btAdapter().dbusPath) : "/org/bluez/hci0", "org.bluez.Adapter1", "Powered", "b", "true"]);
        }
    }

    function btState() {
        return JSON.stringify({
            adapter: root.btAdapter() ? String(root.btAdapter().dbusPath) : null,
            cache: root.btCacheDesc,
            cacheTrusted: root.btCacheTrusted,
            bluezPowered: root.btProbeOn,
            bluezKnown: root.btProbeKnown,
            polling: !root.btCacheTrusted,
            nAdapters: root.modelValues(Bluetooth.adapters).length,
            notified: root.btNotified,
            tick: root.btTick,
            btPresent: root.btPresent,
            btOn: root.btOn,
            btWant: root.btWantOpen ? root.btWantOn : null,
            rfkillFixes: root.btRfkillFixes,
            rfkillWhy: root.btRfkillWhy || null
        });
    }

    function btSetEnabled(want) {
        const a = root.btAdapter();

        root.btWantOn = want;
        root.btWantOpen = true;
        if (want) {
            root.btUnblock("bt on");
            return "rfkill";
        }
        if (a) {
            a.enabled = false;
            return "backend";
        }
        Quickshell.execDetached(["busctl", "--system", "set-property", "org.bluez", "/org/bluez/hci0", "org.bluez.Adapter1", "Powered", "b", "false"]);
        return "busctl";
    }

    function btUnblock(why) {
        root.btRfkillFixes++;
        root.btRfkillWhy = why;
        if (!btUnblockProc.running)
            btUnblockProc.running = true;
        btFallbackTimer.start();
    }

    function pad(n) {
        return n < 10 ? "0" + n : "" + n;
    }

    function timeStr(seconds, h24) {
        const d = new Date();

        if (h24 === false) {
            const h = d.getHours();
            const core = (h % 12 === 0 ? 12 : h % 12) + ":" + root.pad(d.getMinutes()) + (seconds === undefined || seconds ? ":" + root.pad(d.getSeconds()) : "");
            return I18n.t(h < 12 ? "time.12h.am" : "time.12h.pm").replace("%s", core);
        }
        let s = root.pad(d.getHours()) + ":" + root.pad(d.getMinutes());
        if (seconds === undefined || seconds)
            s += ":" + root.pad(d.getSeconds());
        return s;
    }
}
