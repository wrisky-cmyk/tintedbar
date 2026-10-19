pragma Singleton

import QtQuick

QtObject {
    id: lunar

    readonly property int minYear: 1900
    readonly property int maxYear: 2100

    readonly property var info: [0x04bd8, 0x04ae0, 0x0a570, 0x054d5, 0x0d260, 0x0d950, 0x16554, 0x056a0, 0x09ad0, 0x055d2, 0x04ae0, 0x0a5b6, 0x0a4d0, 0x0d250, 0x1d255, 0x0b540, 0x0d6a0, 0x0ada2, 0x095b0, 0x14977, 0x04970, 0x0a4b0, 0x0b4b5, 0x06a50, 0x06d40, 0x1ab54, 0x02b60, 0x09570, 0x052f2, 0x04970, 0x06566, 0x0d4a0, 0x0ea50, 0x06e95, 0x05ad0, 0x02b60, 0x186e3, 0x092e0, 0x1c8d7, 0x0c950, 0x0d4a0, 0x1d8a6, 0x0b550, 0x056a0, 0x1a5b4, 0x025d0, 0x092d0, 0x0d2b2, 0x0a950, 0x0b557, 0x06ca0, 0x0b550, 0x15355, 0x04da0, 0x0a5b0, 0x14573, 0x052b0, 0x0a9a8, 0x0e950, 0x06aa0, 0x0aea6, 0x0ab50, 0x04b60, 0x0aae4, 0x0a570, 0x05260, 0x0f263, 0x0d950, 0x05b57, 0x056a0, 0x096d0, 0x04dd5, 0x04ad0, 0x0a4d0, 0x0d4d4, 0x0d250, 0x0d558, 0x0b540, 0x0b6a0, 0x195a6, 0x095b0, 0x049b0, 0x0a974, 0x0a4b0, 0x0b27a, 0x06a50, 0x06d40, 0x0af46, 0x0ab60, 0x09570, 0x04af5, 0x04970, 0x064b0, 0x074a3, 0x0ea50, 0x06b58, 0x055c0, 0x0ab60, 0x096d5, 0x092e0, 0x0c960, 0x0d954, 0x0d4a0, 0x0da50, 0x07552, 0x056a0, 0x0abb7, 0x025d0, 0x092d0, 0x0cab5, 0x0a950, 0x0b4a0, 0x0baa4, 0x0ad50, 0x055d9, 0x04ba0, 0x0a5b0, 0x15176, 0x052b0, 0x0a930, 0x07954, 0x06aa0, 0x0ad50, 0x05b52, 0x04b60, 0x0a6e6, 0x0a4e0, 0x0d260, 0x0ea65, 0x0d530, 0x05aa0, 0x076a3, 0x096d0, 0x04afb, 0x04ad0, 0x0a4d0, 0x1d0b6, 0x0d250, 0x0d520, 0x0dd45, 0x0b5a0, 0x056d0, 0x055b2, 0x049b0, 0x0a577, 0x0a4b0, 0x0aa50, 0x1b255, 0x06d20, 0x0ada0, 0x14b63, 0x09370, 0x049f8, 0x04970, 0x064b0, 0x168a6, 0x0ea50, 0x06b20, 0x1a6c4, 0x0aae0, 0x0a2e0, 0x0d2e3, 0x0c960, 0x0d557, 0x0d4a0, 0x0da50, 0x05d55, 0x056a0, 0x0a6d0, 0x055d4, 0x052d0, 0x0a9b8, 0x0a950, 0x0b4a0, 0x0b6a6, 0x0ad50, 0x055a0, 0x0aba4, 0x0a5b0, 0x052b0, 0x0b273, 0x06930, 0x07337, 0x06aa0, 0x0ad50, 0x14b55, 0x04b60, 0x0a570, 0x054e4, 0x0d160, 0x0e968, 0x0d520, 0x0daa0, 0x16aa6, 0x056d0, 0x04ae0, 0x0a9d4, 0x0a2d0, 0x0d150, 0x0f252, 0x0d520]

    function leapMonth(y) {
        return lunar.info[y - lunar.minYear] & 0xf;
    }

    function leapDays(y) {
        if (lunar.leapMonth(y))
            return (lunar.info[y - lunar.minYear] & 0x10000) ? 30 : 29;
        return 0;
    }

    function monthDays(y, m) {
        return (lunar.info[y - lunar.minYear] & (0x10000 >> m)) ? 30 : 29;
    }

    function yearDays(y) {
        let sum = 348;
        for (let i = 0x8000; i > 0x8; i >>= 1)
            sum += (lunar.info[y - lunar.minYear] & i) ? 1 : 0;
        return sum + lunar.leapDays(y);
    }

    function fromSolar(y, m, d) {
        if (y < lunar.minYear || y > lunar.maxYear)
            return null;

        let offset = (Date.UTC(y, m - 1, d) - Date.UTC(1900, 0, 31)) / 86400000;
        if (offset < 0)
            return null;

        let i, temp = 0;
        for (i = 1900; i < 2101 && offset > 0; i++) {
            temp = lunar.yearDays(i);
            offset -= temp;
        }
        if (offset < 0) {
            offset += temp;
            i--;
        }
        const year = i;

        const leap = lunar.leapMonth(i);
        let isLeap = false, j;
        for (j = 1; j < 13 && offset > 0; j++) {
            if (leap > 0 && j === leap + 1 && isLeap === false) {
                --j;
                isLeap = true;
                temp = lunar.leapDays(i);
            } else {
                temp = lunar.monthDays(i, j);
            }
            if (isLeap === true && j === leap + 1)
                isLeap = false;
            offset -= temp;
        }

        if (offset === 0 && leap > 0 && j === leap + 1) {
            if (isLeap) {
                isLeap = false;
            } else {
                isLeap = true;
                --j;
            }
        }
        if (offset < 0) {
            offset += temp;
            --j;
        }
        return {
            year: year,
            month: j,
            day: offset + 1,
            isLeap: isLeap
        };
    }

    readonly property var termAngles: [285, 300, 315, 330, 345, 0, 15, 30, 45, 60, 75, 90, 105, 120, 135, 150, 165, 180, 195, 210, 225, 240, 255, 270]

    readonly property var termGuess: [0, 21208, 42467, 63836, 85337, 107014, 128867, 150921, 173149, 195551, 218072, 240693, 263343, 285989, 308563, 331033, 353350, 375494, 397447, 419210, 440795, 462224, 483532, 504758]

    readonly property real rad: Math.PI / 180

    function sunLong(jd) {
        const T = (jd - 2451545.0) / 36525;
        const L0 = 280.46646 + 36000.76983 * T + 0.0003032 * T * T;
        const M = (357.52911 + 35999.05029 * T - 0.0001537 * T * T) * lunar.rad;
        const C = (1.914602 - 0.004817 * T - 0.000014 * T * T) * Math.sin(M) + (0.019993 - 0.000101 * T) * Math.sin(2 * M) + 0.000289 * Math.sin(3 * M);
        const omega = (125.04 - 1934.136 * T) * lunar.rad;
        const lambda = L0 + C - 0.00569 - 0.00478 * Math.sin(omega);
        return ((lambda % 360) + 360) % 360;
    }

    function angleDiff(a, b) {
        return ((a - b) % 360 + 540) % 360 - 180;
    }

    function jdToDate(jd) {
        const z = Math.floor(jd + 0.5);
        const f = jd + 0.5 - z;
        let a = z;
        if (z >= 2299161) {
            const al = Math.floor((z - 1867216.25) / 36524.25);
            a = z + 1 + al - Math.floor(al / 4);
        }
        const b = a + 1524;
        const c = Math.floor((b - 122.1) / 365.25);
        const d0 = Math.floor(365.25 * c);
        const e = Math.floor((b - d0) / 30.6001);
        const day = b - d0 - Math.floor(30.6001 * e) + f;
        const month = e < 14 ? e - 1 : e - 13;
        const year = month > 2 ? c - 4716 : c - 4715;
        return {
            year: year,
            month: month,
            day: Math.floor(day)
        };
    }

    function termDate(y, n) {
        let jd = (31556925974.7 * (y - lunar.minYear) + lunar.termGuess[n] * 60000 + Date.UTC(1900, 0, 6, 2, 5)) / 86400000 + 2440587.5;
        const theta = lunar.termAngles[n];
        for (let i = 0; i < 6; i++) {
            const f = lunar.angleDiff(lunar.sunLong(jd), theta);
            const f2 = lunar.angleDiff(lunar.sunLong(jd + 0.5), theta);
            jd -= f / ((f2 - f) / 0.5);
        }
        return lunar.jdToDate(jd + 8 / 24);
    }

    function solarTermIndex(y, m, d) {
        const n0 = (m - 1) * 2;
        for (let k = 0; k < 2; k++) {
            const t = lunar.termDate(y, n0 + k);
            if (t.month === m && t.day === d)
                return n0 + k;
        }
        return -1;
    }

    readonly property var solarFestivals: ({
            "1-1": "newYear",
            "2-14": "valentine",
            "3-8": "womensDay",
            "5-1": "labour",
            "6-1": "childrensDay",
            "10-1": "national",
            "12-25": "christmas"
        })

    readonly property var lunarFestivals: ({
            "1-1": "spring",
            "1-15": "lantern",
            "5-5": "dragonBoat",
            "7-7": "qixi",
            "7-15": "zhongyuan",
            "8-15": "midAutumn",
            "9-9": "chongyang",
            "12-8": "laba"
        })

    function festivalKey(y, m, d) {
        const s = lunar.solarFestivals[m + "-" + d];
        if (s)
            return s;
        const l = lunar.fromSolar(y, m, d);
        if (!l || l.isLeap)
            return "";
        const k = lunar.lunarFestivals[l.month + "-" + l.day];
        if (k)
            return k;

        if (l.month === 12 && l.day === lunar.monthDays(l.year, 12))
            return "newYearEve";
        return "";
    }
}
