pragma Singleton

import QtQuick
import QtQml
import Quickshell
import Quickshell.Io
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

    function isNerdFamily(name) {
        return /(?:\bNerd\s+Font\b|\bNF(?:M|P)?\b)/i.test(String(name));
    }
    function pickNerdFallback() {
        const installed = root.fontFamilies.filter(root.isNerdFamily);
        if (installed.length === 0)
            return "";

        const styleAlias = /\b(?:Thin|ExtraLight|Light|Regular|Medium|SemiBold|Bold|ExtraBold|Black|Italic)\b/i;
        const monoHint = /\b(?:Mono|Code|Term|Console)\b|JetBrains|Meslo|Fira|Hack|Iosevka|Caskaydia|SauceCode/i;
        installed.sort((a, b) => {
            const as = /symbols/i.test(a), bs = /symbols/i.test(b);
            if (as !== bs)
                return as ? 1 : -1;
            const aa = styleAlias.test(a), ba = styleAlias.test(b);
            if (aa !== ba)
                return aa ? 1 : -1;
            const am = monoHint.test(a), bm = monoHint.test(b);
            if (am !== bm)
                return am ? -1 : 1;
            return String(a).localeCompare(String(b));
        });
        return installed[0];
    }
    readonly property string nerdFallback: pickNerdFallback()
    readonly property string nerd: root.nerdFontOk ? root.nerdFont : root.nerdFallback

    property bool systemDark: true
    property string iconTheme: ""
    property string rawScheme: ""
    property int preferDarkGtk4: -1
    property int preferDarkGtk3: -1

    Process {
        id: schemeInit
        running: true
        command: ["sh", "-c", "gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null" + " | sed 's/^/CS\\t/'; " + "gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null" + " | sed 's/^/IT\\t/'; " + "gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null" + " | sed 's/^/GT\\t/'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const vals = {};
                for (const line of String(text).split("\n")) {
                    const i = line.indexOf("\t");
                    if (i <= 0)
                        continue;
                    vals[line.substring(0, i)] = line.substring(i + 1);
                }
                root.applyColorScheme(vals.CS || "");
                root.applyIconTheme(vals.IT || "");
                root.applyGtkThemeName(vals.GT || "");
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
        onExited: {
            root.schemeMonitorFailures++;
            if (root.schemeMonitorFailures > 5) {
                console.warn("[STYLE] gsettings monitor keeps failing; giving up after " + root.schemeMonitorFailures + " attempts");
                return;
            }

            schemeMonitorRetry.interval = Math.min(60000, 2000 * Math.pow(2, root.schemeMonitorFailures - 1));
            schemeMonitorRetry.restart();
        }
    }
    property int schemeMonitorFailures: 0
    Timer {
        id: schemeMonitorRetry
        interval: 2000
        onTriggered: if (!schemeMonitor.running)
            schemeMonitor.running = true
    }

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || (root.home + "/.config")) + "/gtk-4.0/settings.ini"
        preload: true
        printErrors: false
        watchChanges: true
        onLoaded: {
            root.preferDarkGtk4 = root.parsePreferDark(text());
            root.syncDark();
        }
        onLoadFailed: {
            root.preferDarkGtk4 = -1;
            root.syncDark();
        }
        onFileChanged: reload()
    }
    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || (root.home + "/.config")) + "/gtk-3.0/settings.ini"
        preload: true
        printErrors: false
        watchChanges: true
        onLoaded: {
            root.preferDarkGtk3 = root.parsePreferDark(text());
            root.syncDark();
        }
        onLoadFailed: {
            root.preferDarkGtk3 = -1;
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
        if (v === "1" || v === "true" || v === "yes" || v === "on")
            return 1;
        if (v === "0" || v === "false" || v === "no" || v === "off")
            return 0;

        return -1;
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
        root.schemeMonitorFailures = 0;
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

    property int cssGen: 0
    Process {
        id: cssResolve
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const m = /#CSSGEN (\d+)\s*$/.exec(text);
                if (m && Number(m[1]) !== root.cssGen)
                    return;

                if (!m && text !== "")
                    return;

                root.themeCssOut = m ? text.replace(/#CSSGEN \d+\s*$/, "") : text;
            }
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

            root.cssGen++;
            return;
        }

        if (cssResolve.running) {
            root.cssGen++;
            root.cssResolvePending = true;
            return;
        }
        root.themeCssOut = "";
        root.cssGen++;
        cssResolve.command = ["bash", root.configDir + "/scripts/theme-css.sh", root.gtkThemeName, String(root.cssGen)];
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
        const s = String(v).trim();

        if (/^#[0-9a-f]+$/i.test(s)) {
            const h = s.substring(1).toLowerCase();
            if (h.length === 3)
                return "#" + h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
            if (h.length === 4)
                return "#" + h[3] + h[3] + h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
            if (h.length === 6)
                return "#" + h;
            if (h.length === 8)
                return "#" + h.substring(6) + h.substring(0, 6);
            return "";
        }
        const m = /^rgba?\(([^)]*)\)$/i.exec(s);

        if (!m)
            return /^[a-z]+$/i.test(s) ? s : "";
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
        command: ["sh", "-c", "grep -H -m1 '^@define-color theme_selected_bg_color' " + "\"$HOME\"/.local/share/themes/*/gtk-3.0/gtk-dark.css " + "/usr/share/themes/*/gtk-3.0/gtk-dark.css 2>/dev/null"]
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

    readonly property string version: "26.11.22"
    readonly property string minQuickshellVersion: "0.3.2"
    property string runningQuickshellVersion: ""
    property bool quickshellVersionChecked: false

    function parseVersion(raw) {
        const m = /(?:Quickshell\s+)?(\d+)\.(\d+)(?:\.(\d+))?/.exec(String(raw));
        if (!m)
            return null;
        return [Number(m[1]), Number(m[2]), Number(m[3] || 0)];
    }
    function versionAtLeast(raw, minimum) {
        const have = root.parseVersion(raw);
        const need = root.parseVersion(minimum);
        if (have === null || need === null)
            return null;
        for (let i = 0; i < 3; i++) {
            if (have[i] !== need[i])
                return have[i] > need[i];
        }
        return true;
    }
    function checkQuickshellVersion(raw) {
        if (root.quickshellVersionChecked)
            return;
        root.quickshellVersionChecked = true;
        const parsed = root.parseVersion(raw);
        root.runningQuickshellVersion = parsed === null ? "" : parsed.slice(0, 3).join(".");
        const ok = root.versionAtLeast(raw, root.minQuickshellVersion);
        if (ok === false)
            console.warn("[QS] quickshell " + root.runningQuickshellVersion + " detected, this config requires >= " + root.minQuickshellVersion);
        else if (ok === null)
            console.warn("[QS] cannot detect quickshell version, this config requires >= " + root.minQuickshellVersion);
    }
    Process {
        id: versionProbe
        running: true
        command: ["quickshell", "--version"]
        stdout: StdioCollector {

            onStreamFinished: root.checkQuickshellVersion(text)
        }
    }

    readonly property string fingerprintCmd: "find shell.qml components scripts icons -type f ! -name '.*' ! -name '*~' ! -name '*.swp' -print0 | LC_ALL=C sort -z | xargs -0 sha256sum | sha256sum | cut -c1-8"
    property string packedFingerprint: ""
    property string packedPackaging: ""
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
                root.packedFingerprint = String(o.fingerprint || "");
                root.packedPackaging = String(o.packaging || "");
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

    property bool debug: Quickshell.env("QS_DEBUG") === "1"

    readonly property string home: Quickshell.env("HOME") || Quickshell.env("TMPDIR") || "/tmp"

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (root.home + "/.local/state")) + "/quickshell"

    readonly property string configDir: Quickshell.shellDir

    function modelValues(model) {
        return Compositor.modelValues(model);
    }

    property var desktopEntryCache: Object.create(null)

    function appForClass(cls) {
        if (!cls)
            return null;
        const c = String(cls);
        const key = c.toLowerCase();
        if (Object.prototype.hasOwnProperty.call(root.desktopEntryCache, key))
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
            console.warn("[FONT] preferred cjk font \"" + root.cjkFont + "\" missing" + (root.cjk !== "" ? ", using \"" + root.cjk + "\"" : ", no fallback"));
        if (!root.nerdFontOk)
            console.warn("[FONT] preferred nerd font \"" + root.nerdFont + "\" missing" + (root.nerd !== "" ? ", using \"" + root.nerd + "\"" : ", no fallback (nerd icon glyphs will be missing)"));
        DesktopEntries.applicationsChanged.connect(() => {
            root.desktopEntryCache = Object.create(null);
        });
        BtState.btSync();
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
        if (app && app.icon) {
            const ic = String(app.icon);
            if (out.indexOf(ic) < 0)
                out.push(ic);
            const lic = ic.toLowerCase();
            if (lic !== ic && out.indexOf(lic) < 0)
                out.push(lic);
        }
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

    function gvStr(v) {
        return "'" + String(v).replace(/\\/g, "\\\\").replace(/'/g, "\\'") + "'";
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
            "org.telegram.desktop": "\uF2C6",
            "wechat": "\uF1D7",
            "thunar": "\uEA83",
            "qq": "\uF1D6",
            "micro": "\uF044",
            "mpv": "\uF36E",
            "fcitx": "\uF11C",
            "baidunetdisk": "\uEAC2",
            "binance": "\uF10F",
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
        return NetState.connectedWifi();
    }
    function connectedWired() {
        return NetState.connectedWired();
    }
    function wiredDevice() {
        return NetState.wiredDevice();
    }
    function wifiDevice() {
        return NetState.wifiDevice();
    }
    function wiredNetwork() {
        return NetState.wiredNetwork();
    }
    function netToggleWifiLink() {
        return NetState.netToggleWifiLink();
    }
    function netToggleWiredLink() {
        return NetState.netToggleWiredLink();
    }
    function netToggleLink() {
        return NetState.netToggleLink();
    }
    function netState() {
        return NetState.netState();
    }
    function isTunnelIface(name) {
        return NetState.isTunnelIface(name);
    }

    function forceBranch(list, uid) {
        if (list.length === 0)
            return "plain";
        return gracefulCandidates(list, uid).length > 0 ? "graceful" : "fallback";
    }
    function gracefulCandidates(list, uid) {
        const pids = [];
        for (const b of list)
            if (b.pid > 0 && b.uid >= 0 && b.uid === uid)
                pids.push(b.pid);
        return pids;
    }

    function laptopBattery() {
        for (const d of root.modelValues(UPower.devices)) {
            if (d && d.isLaptopBattery && d.isPresent)
                return d;
        }
        return null;
    }

    readonly property bool btOn: BtState.btOn
    readonly property bool btPresent: BtState.btPresent
    function btState() {
        return BtState.btState();
    }
    function btSetEnabled(want) {
        return BtState.btSetEnabled(want);
    }
    function connectedBtDevice() {
        return BtState.connectedBtDevice();
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

    function probePanelApp(cmd) {
        const words = String(cmd[0]).trim().split(/\s+/);
        const argv = ["bash", "-c", 'exec "$@"', "sh"].concat(words, cmd.slice(1));
        Quickshell.execDetached(argv);
        if (panelBinProbe.running)
            return;

        panelBinProbe.round++;
        panelBinProbe.myRound = panelBinProbe.round;
        panelBinProbe.name = words[0];
        panelBinProbe.command = ["sh", "-c", 'command -v "$1" >/dev/null 2>&1 || echo missing', "sh", words[0]];
        panelBinProbe.running = true;
    }

    function notifyMissingBin(name) {
        Style.notifySimple(I18n.t("hint.appMissing"), name);
    }

    function notifySimple(title, body) {
        if (notifyProc.running) {
            root.notifyPending = {
                title: title,
                body: body
            };
            return;
        }
        notifyProc.command = ["gdbus", "call", "--session", "--dest", "org.freedesktop.Notifications", "--object-path", "/org/freedesktop/Notifications", "--method", "org.freedesktop.Notifications.Notify", "quickshell", "0", "", title, body, "[]", "{\"urgency\": <byte 1>}", 4000];
        notifyProc.running = true;
    }

    property var notifyPending: null

    Process {
        id: notifyProc
        running: false
        onExited: code => {
            if (code !== 0)
                console.warn("[NOTIFY] gdbus notify failed, exit " + code);
            const q = root.notifyPending;
            root.notifyPending = null;
            if (q)
                root.notifySimple(q.title, q.body);
        }
    }

    Process {
        id: panelBinProbe
        property string name: ""
        property int round: 0
        property int myRound: 0
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (panelBinProbe.myRound === panelBinProbe.round && panelBinProbe.name !== "" && String(text).trim() !== "")
                    root.notifyMissingBin(panelBinProbe.name);
                if (panelBinProbe.myRound === panelBinProbe.round)
                    panelBinProbe.name = "";
            }
        }
    }
}
