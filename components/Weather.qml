import QtQuick
import Quickshell
import Quickshell.Io
import "."

Item {
    id: wx

    readonly property string home: Quickshell.env("HOME") || Quickshell.env("TMPDIR") || "/tmp"

    readonly property string confPath: Style.configDir + "/weather.conf"
    readonly property string stateDir: Style.stateDir
    readonly property string cachePath: wx.stateDir + "/weather.json"

    property bool enabled: false

    property real lat: 0
    property real lon: 0

    property string city: ""

    readonly property bool located: wx.lat !== 0 && wx.lon !== 0

    property var current: null
    property var daily: []

    property bool stale: false

    property double fetchedAt: 0

    property string _requestUrl: ""

    readonly property bool ok: wx.current !== null

    readonly property bool ready: wx.enabled && wx.located && wx.ok

    readonly property bool refreshing: weatherPoller.running

    property string wxState: "idle"
    function setState(s) {
        if (wx.wxState === s)
            return;
        if (wx.wxState === "retry-wait")
            retryTimer.stop();
        if (wx.wxState === "wake-wait")
            wakeDelay.stop();
        wx.wxState = s;
    }

    function refresh() {
        if (!wx.enabled || !wx.located)
            return false;
        return weatherPoller.kickAfterExit();
    }

    readonly property int refreshMs: 30 * 60 * 1000

    readonly property int staleAfterMs: 3 * 3600 * 1000

    readonly property string url: "https://api.open-meteo.com/v1/forecast" + "?latitude=" + wx.lat + "&longitude=" + wx.lon + "&current=temperature_2m,apparent_temperature,relative_humidity_2m," + "wind_speed_10m,weather_code,is_day" + "&daily=weather_code,temperature_2m_max,temperature_2m_min" + "&timezone=auto&forecast_days=7"

    property string fallbackIp: ""
    property bool useResolve: false

    property bool fallbackKickPending: false

    function fetchCommand() {
        const cmd = ["curl", "-fsS", "-m", "20", "--connect-timeout", "5", "--max-filesize", "1048576"];
        if (wx.useResolve && wx.fallbackIp !== "")
            cmd.push("--resolve", "api.open-meteo.com:443:" + wx.fallbackIp);
        cmd.push(wx.url);
        return cmd;
    }

    function probeFallbackIp() {
        if (!fallbackIpProbe.running)
            fallbackIpProbe.running = true;
    }
    Process {
        id: fallbackIpProbe
        running: false
        command: ["timeout", "3", "getent", "ahostsv4", "open-meteo.com"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const line = String(text).trim().split("\n")[0] || "";
                const ip = (line.split(/\s+/)[0] || "").trim();
                if (!/^\d{1,3}(\.\d{1,3}){3}$/.test(ip)) {
                    wx.fallbackKickPending = false;
                    return;
                }
                if (ip !== wx.fallbackIp)
                    console.log("[WX] direct path blocked, fallback IP " + ip);
                wx.fallbackIp = ip;
                if (!wx.fallbackKickPending)
                    return;
                wx.fallbackKickPending = false;
                if (wx.useResolve && wx.enabled && wx.located)
                    weatherPoller.kickAfterExit();
            }
        }
    }

    Poller {
        id: weatherPoller

        active: wx.enabled && wx.located
        interval: wx.refreshMs

        command: wx.fetchCommand()
        onStarted: {
            wx._requestUrl = wx.url;
            wx.setState("fetching");
        }

        onActiveChanged: {
            if (active && running && wx._requestUrl !== wx.url)
                weatherPoller.kickAfterExit();
        }
        onOutput: text => wx.absorb(text)
    }

    property int retryStep: 0
    readonly property var retryDelays: [60 * 1000, 300 * 1000]
    function scheduleRetry() {
        if (!wx.enabled || !wx.located) {
            wx.setState("idle");
            return;
        }
        if (wx.retryStep >= wx.retryDelays.length) {
            wx.setState("idle");
            return;
        }
        retryTimer.interval = wx.retryDelays[wx.retryStep++];
        retryTimer.restart();
        wx.setState("retry-wait");
    }
    Timer {
        id: retryTimer
        repeat: false

        onTriggered: weatherPoller.kick()
    }

    onEnabledChanged: if (!wx.enabled) {
        wx.setState("idle");
        wx.retryStep = 0;
        wx.useResolve = false;
        wx.fallbackIp = "";
        wx.fallbackKickPending = false;
    }
    onLocatedChanged: if (!wx.located) {
        wx.setState("idle");
        wx.retryStep = 0;
        wx.useResolve = false;
        wx.fallbackIp = "";
        wx.fallbackKickPending = false;
    }

    property double lastTickMs: 0
    Timer {
        interval: 5000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            const now = Date.now();
            if (wx.lastTickMs === 0) {
                wx.lastTickMs = now;
                return;
            }
            const gap = now - wx.lastTickMs;
            wx.lastTickMs = now;
            if (gap < 15000)
                return;
            wx.retryStep = 0;
            wx.setState("wake-wait");
            if (!wx.enabled || !wx.located) {
                wx.setState("idle");
                return;
            }

            console.log("[WX] wake: gap " + Math.round(gap / 1000) + "s, refetch in 3s");
            weatherPoller.stop();

            wx._requestUrl = "";

            wakeDelay.restart();
        }
    }
    Timer {
        id: wakeDelay
        interval: 3000
        repeat: false

        onTriggered: {
            if (!wx.enabled || !wx.located) {
                wx.setState("idle");
                return;
            }
            weatherPoller.kickAfterExit();
        }
    }

    function absorb(text) {
        if (wx._requestUrl !== wx.url) {
            if (wx.wxState !== "wake-wait" && wx.enabled && wx.located)
                weatherPoller.kickAfterExit();
            return;
        }
        let obj = null;
        try {
            obj = JSON.parse(text);
        } catch (e) {
            obj = null;
        }

        if (!obj || !obj.current || !obj.daily || !wx.applyPayload(obj)) {
            if (wx.ok)
                wx.stale = true;

            console.log("[WX] fetch failed (empty or invalid payload)" + (wx.retryStep < wx.retryDelays.length ? ", retry " + (wx.retryStep + 1) + "/" + wx.retryDelays.length : ", no retry left (next 30min tick)"));

            const netFailed = String(text).trim() === "";
            if (netFailed) {
                const directFailed = !(wx.useResolve && wx.fallbackIp !== "");
                wx.useResolve = true;
                if (directFailed)
                    wx.fallbackKickPending = true;
                wx.probeFallbackIp();
            } else if (wx.useResolve) {
                wx.useResolve = false;
                wx.fallbackIp = "";
                wx.fallbackKickPending = false;
            }
            wx.scheduleRetry();
            return;
        }
        wx.stale = false;
        wx.useResolve = false;
        wx.fallbackIp = "";
        wx.fallbackKickPending = false;
        wx.retryStep = 0;
        wx.setState("idle");
        wx.fetchedAt = Date.now();
        wx.cacheSave(obj);
    }

    function num(v) {
        if (v === null || v === undefined)
            return NaN;
        if (typeof v === "string" && v.trim() === "")
            return NaN;
        const n = Number(v);
        return isFinite(n) ? n : NaN;
    }

    function applyPayload(p) {
        const cur = p.current || {};
        const temp = wx.num(cur.temperature_2m);
        const feels = wx.num(cur.apparent_temperature);
        const humidity = wx.num(cur.relative_humidity_2m);
        const wind = wx.num(cur.wind_speed_10m);
        const code = wx.num(cur.weather_code);
        const isDay = wx.num(cur.is_day);
        if (!isFinite(temp) || !isFinite(feels) || !isFinite(humidity) || !isFinite(wind) || !isFinite(code) || !isFinite(isDay))
            return false;

        const curOut = {
            temp: temp,
            feels: feels,
            humidity: humidity,
            wind: wind,
            code: code,
            isDay: isDay === 1
        };
        const d = p.daily || {};
        const time = d.time || [];
        const codes = d.weather_code || [];
        const maxs = d.temperature_2m_max || [];
        const mins = d.temperature_2m_min || [];
        const out = [];
        for (let i = 0; i < time.length; i++) {
            const dc = wx.num(codes[i]);
            const dmax = wx.num(maxs[i]);
            const dmin = wx.num(mins[i]);
            const date = (time[i] === null || time[i] === undefined) ? "" : String(time[i]);

            if (date === "" || !/^\d{4}-\d{2}-\d{2}$/.test(date) || !isFinite(dc) || !isFinite(dmax) || !isFinite(dmin))
                return false;
            out.push({
                date: date,
                code: dc,
                max: dmax,
                min: dmin
            });
        }
        wx.current = curOut;
        wx.daily = out;
        return true;
    }

    function cacheSave(payload) {
        wx.cachePending = payload;
        cacheStore.requestSave();
    }
    property var cachePending: null

    JsonStore {
        id: cacheStore
        path: wx.cachePath
        loadOnStart: false
        loaded: true
        debounceMs: 0
        serialize: () => JSON.stringify({
                at: Date.now(),
                data: wx.cachePending
            })
    }

    Process {
        id: cacheLoad
        running: true
        command: ["sh", "-c", Style.readJsonCmd(wx.cachePath, "{}")]
        stdout: StdioCollector {
            onStreamFinished: {
                if (wx.ok && !wx.stale)
                    return;
                let saved = {};
                try {
                    saved = JSON.parse(text);
                } catch (e) {
                    saved = {};
                }
                if (!saved || !saved.data || !saved.data.current)
                    return;
                if (!wx.applyPayload(saved.data))
                    return;
                if (saved.at && (Date.now() - saved.at) > wx.staleAfterMs)
                    wx.stale = true;

                if (saved.at)
                    wx.fetchedAt = Number(saved.at);
            }
        }
    }

    function absorbConf(text) {
        const oldLat = wx.lat;
        const oldLon = wx.lon;
        let la = 0, lo = 0;
        let cityVal = "";
        for (const raw of String(text === undefined ? "" : text).split("\n")) {
            if (/^\s*#/.test(raw))
                continue;
            const line = raw.trim();
            const eq = line.indexOf("=");
            if (eq <= 0)
                continue;
            const key = line.slice(0, eq).trim().toLowerCase();
            let val = line.slice(eq + 1).trim();

            const ci = val.search(/\s#/);
            if (ci >= 0)
                val = val.slice(0, ci).trim();

            if (key === "city") {
                cityVal = val;
                continue;
            }
            const n = Number(val);
            if (!isFinite(n))
                continue;

            if (key === "lat" || key === "latitude") {
                if (Math.abs(n) <= 90)
                    la = n;
            } else if (key === "lon" || key === "lng" || key === "longitude") {
                if (Math.abs(n) <= 180)
                    lo = n;
            }
        }
        wx.lat = la;
        wx.lon = lo;
        wx.city = cityVal;

        if (la !== oldLat || lo !== oldLon) {
            wx.stale = true;
            if (wx.enabled && wx.located)
                weatherPoller.kickAfterExit();
        }
    }

    FileView {
        path: wx.confPath
        preload: true
        printErrors: false
        watchChanges: true
        onLoaded: {
            wx.absorbConf(text());
        }

        onFileChanged: reload()
    }

    function wmoKey(code) {
        switch (Number(code)) {
        case 0:
            return "clear";
        case 1:
            return "mainly";
        case 2:
            return "cloudy";
        case 3:
            return "overcast";
        case 45:
        case 48:
            return "fog";
        case 51:
        case 53:
        case 55:
            return "drizzle";
        case 56:
        case 57:
            return "freezingDrizzle";
        case 61:
        case 63:
        case 65:
            return "rain";
        case 66:
        case 67:
            return "freezingRain";
        case 71:
        case 73:
        case 75:
            return "snow";
        case 77:
            return "snowGrains";
        case 80:
        case 81:
        case 82:
            return "showers";
        case 85:
        case 86:
            return "snowShowers";
        case 95:
            return "thunder";
        case 96:
        case 99:
            return "thunderHail";
        }
        return "unknown";
    }

    function glyph(code, isDay) {
        const night = isDay === false || isDay === 0;
        switch (wx.wmoKey(code)) {
        case "clear":
            return night ? "\u{F0594}" : "\u{F0599}";
        case "mainly":
            return night ? "\u{F0F31}" : "\u{F0595}";
        case "cloudy":
            return "\u{F0590}";
        case "overcast":
            return "\uE312";
        case "fog":
            return "\u{F0591}";
        case "drizzle":
            return night ? "\uE336" : "\uE30B";
        case "freezingDrizzle":
        case "freezingRain":
            return "\u{F067F}";
        case "rain":
            return "\u{F0597}";
        case "showers":
            return "\u{F0F33}";
        case "snow":
            return "\u{F0598}";
        case "snowGrains":
            return "\u{F0717}";
        case "snowShowers":
            return "\u{F0F34}";
        case "thunder":
            return "\u{F067E}";
        case "thunderHail":
            return "\u{F0592}";
        }
        return "\u{F0590}";
    }

    function dayDate(iso) {
        const p = String(iso).split("-");
        return new Date(Number(p[0]), Number(p[1]) - 1, Number(p[2]));
    }
}
