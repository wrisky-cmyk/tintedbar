import QtQuick

QtObject {
    id: root

    property var launcherByScreen: ({})
    property var clipsByScreen: ({})
    property var powerMenuByScreen: ({})
    property var promptByScreen: ({})
    property var settingsByScreen: ({})
    property var brightnessByScreen: ({})
    property var pomodoroByScreen: ({})
    property var calendarByScreen: ({})
    property var weatherPopupByScreen: ({})
    property var wallpaperPopupByScreen: ({})
    property var trayRowByScreen: ({})

    readonly property var roleMap: ({
            launcher: "launcherByScreen",
            clips: "clipsByScreen",
            powermenu: "powerMenuByScreen",
            prompt: "promptByScreen",
            settings: "settingsByScreen",
            brightness: "brightnessByScreen",
            pomodoro: "pomodoroByScreen",
            calendar: "calendarByScreen",
            weather: "weatherPopupByScreen",
            wallpaper: "wallpaperPopupByScreen",
            tray: "trayRowByScreen"
        })

    function register(key, pairs) {
        for (const role in pairs) {
            const prop = root.roleMap[role];
            if (prop && pairs[role])
                root[prop][key] = pairs[role];
        }
    }

    function unregister(key) {
        for (const role in root.roleMap)
            delete root[root.roleMap[role]][key];
    }

    function forFocused(map, focusedKey) {
        return map[focusedKey] || Object.values(map)[0] || null;
    }

    function setActive(role, key, v) {
        const prop = root.roleMap[role];
        if (!prop)
            return;
        root[prop] = Object.assign({}, root[prop], {
            [key]: v === true
        });
    }
    function activeFlag(role, key) {
        const prop = root.roleMap[role];
        return prop ? root[prop][key] === true : false;
    }

    function snapshot() {
        const out = {};
        for (const role in root.roleMap) {
            const byKey = root[root.roleMap[role]];
            const row = {};
            for (const key of Object.keys(byKey)) {
                const inst = byKey[key];

                row[key] = (typeof inst === "object" && inst !== null) ? {
                    visible: inst.visible === true,
                    w: Math.round(inst.width || 0),
                    h: Math.round(inst.height || 0)
                } : {
                    visible: inst === true,
                    w: 0,
                    h: 0
                };
            }
            out[role] = row;
        }
        return out;
    }
}
