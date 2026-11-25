import QtQuick
import Quickshell.Io
import "."

Item {
    id: themeAuto

    required property var qsRoot
    required property var weather

    readonly property bool active: qsRoot.autoTheme && weather.located

    property string lastTarget: ""

    property string pendingTarget: ""
    property bool toggling: false

    Timer {
        id: poll
        interval: 60000
        repeat: false
        running: false
        onTriggered: themeAuto.checkTarget()
    }

    onActiveChanged: {
        if (active)
            checkTarget();
        else
            poll.stop();
    }

    Connections {
        target: themeAuto.qsRoot ? themeAuto.qsRoot : null
        function onAutoThemeChanged() {
            if (!themeAuto.qsRoot.barSettingsLoaded)
                return;
            if (themeAuto.qsRoot.autoTheme && !themeAuto.weather.located)
                themeAuto.warnNoLocation();
        }
    }

    function warnNoLocation() {
        if (notifyProc.running)
            return;
        notifyProc.running = true;
    }

    Process {
        id: notifyProc
        running: false
        command: ["gdbus", "call", "--timeout", "3", "--session", "--dest", "org.freedesktop.Notifications", "--object-path", "/org/freedesktop/Notifications", "--method", "org.freedesktop.Notifications.Notify", "quickshell", "0", "", I18n.t("autoTheme.noLocation"), I18n.t("autoTheme.noLocationBody"), "[]", "{\"urgency\": <byte 1>}", "8000"]
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "")
                    console.log("[AUTOTHEME] notify stderr: " + text.trim());
            }
        }
        onExited: code => {
            if (code !== 0)
                console.log("[AUTOTHEME] notify failed, gdbus exit " + code);
        }
    }

    function checkTarget() {
        if (!themeAuto.active)
            return;
        const now = new Date();
        const t = themeAuto.targetMode(now, weather.lat, weather.lon);

        if (t !== "" && t !== themeAuto.lastTarget && t !== themeAuto.pendingTarget) {
            themeAuto.pendingTarget = t;
            modeCheck.running = true;
        }
        scheduleNext(now);
    }

    function scheduleNext(now) {
        if (!themeAuto.active)
            return;
        let nextMs = 12 * 3600 * 1000;
        const s = themeAuto.sunMinutes(now, weather.lat, weather.lon);
        const nowMin = now.getHours() * 60 + now.getMinutes();
        if (s) {
            for (const c of [s.sunrise, s.sunset, s.sunrise + 1440, s.sunset + 1440]) {
                if (c > nowMin) {
                    nextMs = (c - nowMin) * 60000;
                    break;
                }
            }
        }
        poll.interval = Math.max(60000, Math.min(nextMs, 12 * 3600 * 1000));
        poll.restart();
    }

    function sunMinutes(date, lat, lon) {
        const rad = Math.PI / 180;
        const start = Date.UTC(date.getUTCFullYear(), 0, 0);
        const doy = Math.floor((date.getTime() - start) / 86400000);
        const frac = (date.getUTCHours() + date.getUTCMinutes() / 60 - 12) / 24;
        const gamma = 2 * Math.PI / 365 * (doy - 1 + frac);
        const eqtime = 229.18 * (0.000075 + 0.001868 * Math.cos(gamma) - 0.032077 * Math.sin(gamma) - 0.014615 * Math.cos(2 * gamma) - 0.040849 * Math.sin(2 * gamma));
        const decl = 0.006918 - 0.399912 * Math.cos(gamma) + 0.070257 * Math.sin(gamma) - 0.006758 * Math.cos(2 * gamma) + 0.000907 * Math.sin(2 * gamma) - 0.002697 * Math.cos(3 * gamma) + 0.00148 * Math.sin(3 * gamma);
        const cosHa = Math.cos(90.833 * rad) / (Math.cos(lat * rad) * Math.cos(decl)) - Math.tan(lat * rad) * Math.tan(decl);
        if (cosHa > 1 || cosHa < -1)
            return null;
        const ha = Math.acos(cosHa) / rad;
        const tz = -date.getTimezoneOffset();

        const wrap = m => ((m % 1440) + 1440) % 1440;
        return {
            sunrise: wrap(720 - 4 * (lon + ha) - eqtime + tz),
            sunset: wrap(720 - 4 * (lon - ha) - eqtime + tz)
        };
    }

    function targetMode(date, lat, lon) {
        const s = themeAuto.sunMinutes(date, lat, lon);
        if (!s)
            return "";
        const nowMin = date.getHours() * 60 + date.getMinutes();
        return (nowMin >= s.sunrise && nowMin < s.sunset) ? "light" : "dark";
    }

    Process {
        id: modeCheck
        running: false
        command: ["sh", "-c", "exec " + Style.sq(Style.configDir + "/scripts/theme-apply.sh") + " --mode"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                if (!themeAuto.active) {
                    themeAuto.pendingTarget = "";
                    return;
                }
                const cur = String(text).trim();

                if (cur === "")
                    return;
                if (cur === themeAuto.pendingTarget) {
                    themeAuto.lastTarget = themeAuto.pendingTarget;
                    themeAuto.pendingTarget = "";
                    return;
                }
                if (!themeAuto.toggling) {
                    themeAuto.toggling = true;
                    toggleProc.running = true;
                }
            }
        }
    }

    Process {
        id: toggleProc
        running: false
        command: ["sh", "-c", "exec " + Style.sq(Style.configDir + "/scripts/theme-toggle.sh")]
        onExited: {
            themeAuto.toggling = false;

            if (themeAuto.active && themeAuto.pendingTarget !== "")
                modeCheck.running = true;
        }
    }
}
