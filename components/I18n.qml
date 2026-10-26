pragma Singleton

import QtQuick
import Quickshell
import "."

QtObject {
    id: i18n

    readonly property var languages: [
        {
            code: "zh",
            name: "中文",
            match: ["zh"],
            strings: {
                "panel.idle": "锁屏与息屏",
                "panel.general": "通用",
                "panel.language": "语言",
                "panel.palette": "配色",
                "panel.barHeight": "栏宽",
                "panel.idleLock": "自动锁屏（分钟）",
                "panel.idleDpms": "自动息屏（分钟）",
                "panel.notifications": "通知",
                "panel.historyLimit": "保留条数",
                "panel.dnd": "勿扰模式",
                "panel.modules": "模块",
                "panel.version": "版本",
                "lang.auto": "跟随系统",
                "flag.showClips": "剪贴板",
                "flag.showBattery": "电池",
                "flag.showNetSpeed": "网速",
                "flag.showNetIface": "SSID",
                "flag.showBtDevice": "蓝牙设备",
                "flag.showClockSeconds": "时钟带秒",
                "flag.showLunar": "农历/节日",
                "flag.showWeather": "天气",
                "flag.showTerminal": "终端",
                "flag.showBrowser": "浏览器",
                "flag.showFilemanager": "文件管理器",
                "flag.showTemperature": "CPU 温度",
                "flag.showDisk": "磁盘占用",
                "flag.showCpu": "CPU 占用",
                "flag.showMemory": "内存占用",
                "flag.showIdleInhibitor": "禁止锁屏与息屏",
                "flag.fullscreenIdleInhibit": "全屏时禁止锁屏与息屏",
                "flag.showMpris": "正在播放",
                "flag.showPpd": "电源模式",
                "flag.showPrivacy": "隐私保护",
                "flag.showKeyboard": "Num/Caps",
                "flag.showLanguage": "键盘布局",
                "flag.showReboot": "重启提示",
                "flag.showBrightness": "亮度调节",
                "flag.clock24": "24 小时制",
                "flag.fullscreenDnd": "全屏免打扰",
                "time.12h.am": "上午%s",
                "time.12h.pm": "下午%s",
                "palette.auto": "跟随系统主题",
                "palette.tinted": "Tinted",
                "palette.cyan": "Tinted-Cyan",
                "palette.sea": "Tinted-Sea",
                "palette.green": "Tinted-Green",
                "palette.khaki": "Tinted-Khaki",
                "palette.orange": "Tinted-Orange",
                "palette.red": "Tinted-Red",
                "palette.pink": "Tinted-Pink",
                "palette.violet": "Tinted-Violet",
                "launcher.search": "搜索应用…",
                "calc.copy": "回车复制",
                "clips.search": "搜索剪贴板…",
                "clips.show": "显示",
                "clips.clear": "清空",
                "clips.empty": "暂无剪贴板历史",
                "clips.noMatch": "没有匹配的条目",
                "notif.title": "通知",
                "notif.clearAll": "全部删除",
                "notif.empty": "暂无通知",
                "notif.ignore": "忽略",
                "power.lock": "锁定",
                "power.logout": "注销",
                "power.suspend": "睡眠",
                "power.hibernate": "休眠",
                "power.shutdown": "关机",
                "power.reboot": "重启",
                "wx.today": "今天",
                "wx.tomorrow": "明天",
                "wx.feels": "体感",
                "wx.humidity": "湿度",
                "wx.wind": "风",
                "wx.c.clear": "晴",
                "wx.c.mainly": "晴间多云",
                "wx.c.cloudy": "多云",
                "wx.c.overcast": "阴",
                "wx.c.fog": "雾",
                "wx.c.drizzle": "毛毛雨",
                "wx.c.freezingDrizzle": "冻毛毛雨",
                "wx.c.rain": "雨",
                "wx.c.freezingRain": "冻雨",
                "wx.c.snow": "雪",
                "wx.c.snowGrains": "米雪",
                "wx.c.showers": "阵雨",
                "wx.c.snowShowers": "阵雪",
                "wx.c.thunder": "雷阵雨",
                "wx.c.thunderHail": "雷暴冰雹",
                "wx.c.unknown": "—",
                "lock.placeholder": "输入密码…",
                "lock.attempts": "错误 {n} 次",
                "lock.pamUnavailable": "认证服务不可用",
                "lock.failed": "密码错误",
                "lock.retry": "尝试过多 · {n}s 后可重试",
                "lock.hint": "Enter 解锁 · Esc 清空",
                "lock.capsOn": "Caps Lock 已开",
                "reboot.title": "该重启了",
                "reboot.reloginTitle": "该重登录了",
                "reboot.action": "现在重启",
                "reboot.reloginAction": "现在注销",
                "reboot.kernelItems": "内核已更新：{names}",
                "reboot.moduleItems": "模块已更新：{names}",
                "reboot.libItems": "用户态文件已更新：{names}{files}",
                "reboot.kernelCount": "内核镜像已更新（{n} 个）",
                "reboot.moduleCount": "第三方模块已更新（{n} 个）",
                "reboot.libCount": "用户态文件已更新（{n} 个）",
                "reboot.moreItems": "等 {n} 项",
                "reboot.fileCount": "（{n} 个文件）",
                "reboot.sepList": "、",
                "polkit.title": "需要授权",
                "polkit.password": "输入密码…",
                "polkit.verifying": "验证中…",
                "polkit.authenticate": "验证",
                "polkit.cancel": "取消",
                "polkit.failed": "密码错误",
                "polkit.hint": "Enter 验证 · Esc 取消",
                "polkit.capsOn": "Caps Lock 已开",
                "mic.muted": "静音"
            },
            date: {
                weekdays: ["日", "一", "二", "三", "四", "五", "六"],
                calHeaders: ["一", "二", "三", "四", "五", "六", "日"],
                wdTemplate: "星期{WD}",
                wdSample: "星期三",
                wdShortTemplate: "周{WD}",
                dayTemplate: "{m}月{d}日",
                daySample: "12月31日",
                titleTemplate: "{y} 年 {m} 月",
                lunar: {
                    leap: "闰",
                    months: ["正月", "二月", "三月", "四月", "五月", "六月", "七月", "八月", "九月", "十月", "冬月", "腊月"],
                    days: ["初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十", "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十", "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"],
                    terms: ["小寒", "大寒", "立春", "雨水", "惊蛰", "春分", "清明", "谷雨", "立夏", "小满", "芒种", "夏至", "小暑", "大暑", "立秋", "处暑", "白露", "秋分", "寒露", "霜降", "立冬", "小雪", "大雪", "冬至"],
                    festivals: {
                        newYear: "元旦",
                        valentine: "情人节",
                        womensDay: "妇女节",
                        labour: "劳动节",
                        childrensDay: "儿童节",
                        national: "国庆节",
                        christmas: "圣诞节",
                        spring: "春节",
                        lantern: "元宵",
                        dragonBoat: "端午",
                        qixi: "七夕",
                        zhongyuan: "中元",
                        midAutumn: "中秋",
                        chongyang: "重阳",
                        laba: "腊八",
                        newYearEve: "除夕"
                    }
                },
                almanac: {
                    gan: ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"],
                    zhi: ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"],
                    zodiac: ["鼠", "牛", "虎", "兔", "龙", "蛇", "马", "羊", "猴", "鸡", "狗", "猪"],
                    gzYear: "{gz}{zodiac}年",
                    gzDay: "{gz}日",
                    moonPhases: ["朔", "蛾眉月", "上弦", "盈凸月", "望", "亏凸月", "下弦", "残月"],
                    termToday: "今日{term}",
                    termTomorrow: "明天{term}",
                    termDays: "距{term} {n} 天"
                }
            }
        },
        {
            code: "en",
            name: "English",
            match: ["en"],
            strings: {
                "panel.idle": "Idle inhibit",
                "panel.general": "General",
                "panel.language": "Language",
                "panel.palette": "Palette",
                "panel.barHeight": "Bar height",
                "panel.idleLock": "Auto-lock (min)",
                "panel.idleDpms": "Screen off (min)",
                "panel.notifications": "Notifications",
                "panel.historyLimit": "History size",
                "panel.dnd": "Do not disturb",
                "panel.modules": "Modules",
                "panel.version": "Version",
                "lang.auto": "Auto",
                "flag.showClips": "Clipboard",
                "flag.showBattery": "Battery",
                "flag.showNetSpeed": "Net speed",
                "flag.showNetIface": "Network name",
                "flag.showBtDevice": "Bluetooth device",
                "flag.showClockSeconds": "Clock seconds",
                "flag.showLunar": "Lunar/holidays",
                "flag.showWeather": "Weather",
                "flag.showTerminal": "Terminal",
                "flag.showBrowser": "Browser",
                "flag.showFilemanager": "File manager",
                "flag.showTemperature": "CPU temp",
                "flag.showDisk": "Disk",
                "flag.showCpu": "CPU",
                "flag.showMemory": "Memory",
                "flag.showIdleInhibitor": "Inhibit",
                "flag.fullscreenIdleInhibit": "Fullscreen inhibit",
                "flag.showMpris": "Now playing",
                "flag.showPpd": "Power profile",
                "flag.showPrivacy": "Privacy",
                "flag.showKeyboard": "Num/Caps",
                "flag.showLanguage": "Keyboard layout",
                "flag.showReboot": "Reboot hint",
                "flag.showBrightness": "Brightness",
                "flag.clock24": "24-hour clock",
                "flag.fullscreenDnd": "Fullscreen DND",
                "mic.muted": "Muted",
                "time.12h.am": "%s AM",
                "time.12h.pm": "%s PM",
                "palette.auto": "Auto (follow theme)",
                "palette.tinted": "Tinted",
                "palette.cyan": "Tinted-Cyan",
                "palette.sea": "Tinted-Sea",
                "palette.green": "Tinted-Green",
                "palette.khaki": "Tinted-Khaki",
                "palette.orange": "Tinted-Orange",
                "palette.red": "Tinted-Red",
                "palette.pink": "Tinted-Pink",
                "palette.violet": "Tinted-Violet",
                "launcher.search": "Search apps…",
                "calc.copy": "Enter to copy",
                "clips.search": "Search clipboard…",
                "clips.show": "Show",
                "clips.clear": "Clear",
                "clips.empty": "No clipboard history",
                "clips.noMatch": "No matching entries",
                "notif.title": "Notifications",
                "notif.clearAll": "Clear all",
                "notif.empty": "No notifications",
                "notif.ignore": "Ignore",
                "power.lock": "Lock",
                "power.logout": "Log out",
                "power.suspend": "Suspend",
                "power.hibernate": "Hibernate",
                "power.shutdown": "Shut down",
                "power.reboot": "Restart",
                "wx.today": "Today",
                "wx.tomorrow": "Tmrw",
                "wx.feels": "Feels",
                "wx.humidity": "Hum",
                "wx.wind": "Wind",
                "wx.c.clear": "Clear",
                "wx.c.mainly": "Mainly clear",
                "wx.c.cloudy": "Partly cloudy",
                "wx.c.overcast": "Overcast",
                "wx.c.fog": "Fog",
                "wx.c.drizzle": "Drizzle",
                "wx.c.freezingDrizzle": "Freezing drizzle",
                "wx.c.rain": "Rain",
                "wx.c.freezingRain": "Freezing rain",
                "wx.c.snow": "Snow",
                "wx.c.snowGrains": "Snow grains",
                "wx.c.showers": "Showers",
                "wx.c.snowShowers": "Snow showers",
                "wx.c.thunder": "Thunderstorm",
                "wx.c.thunderHail": "Thunderstorm, hail",
                "wx.c.unknown": "—",
                "lock.placeholder": "Input Password…",
                "lock.attempts": "{n} failed",
                "lock.pamUnavailable": "Authentication unavailable",
                "lock.failed": "Incorrect password",
                "lock.retry": "Too many attempts · retry in {n}s",
                "lock.hint": "Enter to unlock · Esc to clear",
                "lock.capsOn": "Caps Lock is on",
                "reboot.title": "Reboot recommended",
                "reboot.reloginTitle": "Re-login recommended",
                "reboot.action": "Reboot now",
                "reboot.reloginAction": "Log out now",
                "reboot.kernelItems": "Kernel updated: {names}",
                "reboot.moduleItems": "Modules updated: {names}",
                "reboot.libItems": "Userspace files updated: {names}{files}",
                "reboot.kernelCount": "Kernel images updated ({n})",
                "reboot.moduleCount": "Out-of-tree modules updated ({n})",
                "reboot.libCount": "Userspace files updated ({n})",
                "reboot.moreItems": "and {n} more",
                "reboot.fileCount": " ({n} files)",
                "reboot.sepList": ", ",
                "polkit.title": "Authorization required",
                "polkit.password": "Input Password…",
                "polkit.verifying": "Verifying…",
                "polkit.authenticate": "Authenticate",
                "polkit.cancel": "Cancel",
                "polkit.failed": "Incorrect password",
                "polkit.hint": "Enter to authorize · Esc to cancel",
                "polkit.capsOn": "Caps Lock is on"
            },
            date: {
                weekdays: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"],
                calHeaders: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
                monthsShort: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"],
                monthsLong: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"],
                wdTemplate: "{WD}",
                wdSample: "Wed",
                wdShortTemplate: "{WD}",
                dayTemplate: "{MON} {d}",
                daySample: "Dec 31",
                titleTemplate: "{MONTH} {y}"
            }
        }
    ]

    readonly property string defaultLang: "en"

    readonly property string systemLang: {
        const raw = (String(Qt.locale().name || "") + " " + String(Quickshell.env("LC_ALL") || "") + " " + String(Quickshell.env("LANG") || "")).toLowerCase();
        const tags = raw.split(/[^a-z]+/);
        for (const l of i18n.languages)
            for (const m of l.match)
                if (tags.indexOf(m) >= 0)
                    return l.code;
        return i18n.defaultLang;
    }

    property string lang: "auto"

    readonly property string effectiveLang: i18n.lang === "auto" ? i18n.systemLang : i18n.lang

    readonly property var langCodes: i18n.languages.map(l => l.code)

    function entryFor(code) {
        for (const l of i18n.languages)
            if (l.code === code)
                return l;
        return null;
    }

    readonly property var langEntry: i18n.entryFor(i18n.effectiveLang) || i18n.languages[0]

    readonly property string langName: {
        if (i18n.lang !== "auto") {
            const e = i18n.entryFor(i18n.lang);
            if (e)
                return e.name;
        }
        return i18n.t("lang.auto");
    }

    function t(key) {
        const s = i18n.langEntry.strings;
        if (s[key] !== undefined)
            return s[key];

        const fb = (i18n.entryFor(i18n.defaultLang) || i18n.languages[0]).strings;
        if (fb[key] !== undefined)
            return fb[key];

        for (const l of i18n.languages)
            if (l.strings[key] !== undefined) {
                console.warn("[I18N] " + i18n.effectiveLang + " 缺 \"" + key + "\", 回退 " + l.code);
                return l.strings[key];
            }
        console.warn("[I18N] 所有语言都缺 \"" + key + "\" —— 补进 languages 的 strings");
        return key;
    }

    function pad(n) {
        return n < 10 ? "0" + n : "" + n;
    }

    function fill(tpl, m) {
        let s = String(tpl);
        for (const k of Object.keys(m).sort((a, b) => b.length - a.length))
            s = s.split("{" + k + "}").join(String(m[k]));
        return s;
    }

    readonly property var weekdayHeaders: i18n.langEntry.date.calHeaders

    function dateParts(seconds, clock24) {
        const d = new Date();
        const dt = i18n.langEntry.date;
        return {
            wd: i18n.fill(dt.wdTemplate, {
                WD: dt.weekdays[d.getDay()]
            }),
            day: i18n.fill(dt.dayTemplate, {
                m: d.getMonth() + 1,
                d: d.getDate(),
                MON: dt.monthsShort ? dt.monthsShort[d.getMonth()] : "",
                MONTH: dt.monthsLong ? dt.monthsLong[d.getMonth()] : ""
            }),
            time: Style.timeStr(seconds, clock24)
        };
    }

    function dateSampleParts(seconds, clock24) {
        const withSec = seconds === undefined || seconds;
        return {
            wd: i18n.langEntry.date.wdSample,
            day: i18n.langEntry.date.daySample,
            time: clock24 === false ? i18n.t("time.12h.am").replace("%s", withSec ? "12:59:59" : "12:59") : (withSec ? "23:59:59" : "23:59")
        };
    }

    function calendarTitle(year, month) {
        const dt = i18n.langEntry.date;
        return i18n.fill(dt.titleTemplate, {
            y: year,
            m: month + 1,
            MON: dt.monthsShort ? dt.monthsShort[month] : "",
            MONTH: dt.monthsLong ? dt.monthsLong[month] : ""
        });
    }

    function weekdayShort(date) {
        const dt = i18n.langEntry.date;
        const tpl = dt.wdShortTemplate !== undefined ? dt.wdShortTemplate : dt.wdTemplate;
        return i18n.fill(tpl, {
            WD: dt.weekdays[date.getDay()]
        });
    }

    function dayMark(date) {
        const names = i18n.langEntry.date.lunar;
        if (!names || !date)
            return {
                text: "",
                kind: ""
            };
        const y = date.getFullYear(), m = date.getMonth() + 1, d = date.getDate();

        const fk = Lunar.festivalKey(y, m, d);
        if (fk && names.festivals && names.festivals[fk])
            return {
                text: names.festivals[fk],
                kind: "festival"
            };

        const ti = Lunar.solarTermIndex(y, m, d);
        if (ti >= 0 && names.terms)
            return {
                text: names.terms[ti],
                kind: "term"
            };

        const l = Lunar.fromSolar(y, m, d);
        if (!l)
            return {
                text: "",
                kind: ""
            };
        if (l.day === 1)
            return {
                text: (l.isLeap ? names.leap : "") + names.months[l.month - 1],
                kind: "lunar"
            };
        return {
            text: names.days[l.day - 1],
            kind: "lunar"
        };
    }

    function almanacToday(date) {
        const a = i18n.langEntry.date.almanac;
        if (!a || !date)
            return null;
        const l = Lunar.fromSolar(date.getFullYear(), date.getMonth() + 1, date.getDate());
        if (!l)
            return null;
        const names = i18n.langEntry.date.lunar;
        const gi = Almanac.dayIndex(date.getFullYear(), date.getMonth() + 1, date.getDate());
        const gy = Almanac.yearIndex(l.year);
        const mi = Almanac.moonPhaseIndex(l.day);
        const word = gi => a.gan[gi % 10] + a.zhi[gi % 12];
        const term = Almanac.nextTerm(date);
        const termName = term && names.terms ? names.terms[term.index] : "";
        return {
            lunar: names ? (l.isLeap ? names.leap : "") + names.months[l.month - 1] + names.days[l.day - 1] : "",
            gzYear: i18n.fill(a.gzYear, {
                gz: word(gy),
                zodiac: a.zodiac[gy % 12]
            }),
            gzDay: i18n.fill(a.gzDay, {
                gz: word(gi)
            }),
            moon: a.moonPhases[mi],
            moonGlyph: Almanac.moonGlyph(mi),
            term: termName === "" ? "" : term.days === 0 ? i18n.fill(a.termToday, {
                term: termName
            }) : term.days === 1 ? i18n.fill(a.termTomorrow, {
                term: termName
            }) : i18n.fill(a.termDays, {
                term: termName,
                n: term.days
            })
        };
    }
}
