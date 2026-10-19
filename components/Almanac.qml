pragma Singleton

import QtQuick
import "."

QtObject {
    id: alm

    function jdn(y, m, d) {
        const a = Math.floor((14 - m) / 12);
        const yy = y + 4800 - a;
        const mm = m + 12 * a - 3;
        return d + Math.floor((153 * mm + 2) / 5) + 365 * yy + Math.floor(yy / 4) - Math.floor(yy / 100) + Math.floor(yy / 400) - 32045;
    }

    function dayIndex(y, m, d) {
        return ((alm.jdn(y, m, d) - 2451545 + 54) % 60 + 60) % 60;
    }

    function yearIndex(lunarYear) {
        return ((lunarYear - 4) % 60 + 60) % 60;
    }

    function moonPhaseIndex(lunarDay) {
        const d = Number(lunarDay);
        if (d <= 1)
            return 0;
        if (d <= 6)
            return 1;
        if (d <= 8)
            return 2;
        if (d <= 14)
            return 3;
        if (d <= 16)
            return 4;
        if (d <= 22)
            return 5;
        if (d <= 24)
            return 6;
        return 7;
    }

    function moonGlyph(phaseIndex) {
        switch (phaseIndex) {
        case 0:
            return "\u{E38D}";
        case 1:
            return "\u{E390}";
        case 2:
            return "\u{E394}";
        case 3:
            return "\u{E397}";
        case 4:
            return "\u{E39B}";
        case 5:
            return "\u{E39E}";
        case 6:
            return "\u{E3A2}";
        }
        return "\u{E3A5}";
    }

    function nextTerm(date) {
        const y = date.getFullYear();
        const today = alm.jdn(y, date.getMonth() + 1, date.getDate());
        for (const yy of [y - 1, y, y + 1]) {
            for (let n = 0; n < 24; n++) {
                const t = Lunar.termDate(yy, n);
                const j = alm.jdn(t.year, t.month, t.day);
                if (j >= today)
                    return {
                        index: n,
                        days: j - today,
                        month: t.month,
                        day: t.day
                    };
            }
        }
        return null;
    }
}
