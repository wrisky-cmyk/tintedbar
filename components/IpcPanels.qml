import QtQuick
import Quickshell.Io

Item {
    id: root

    required property var qsRoot
    required property var notifCenter

    function focusedPanel(map) {
        return root.qsRoot.panelForFocused(map);
    }
    function togglePanel(map) {
        const l = focusedPanel(map);
        if (l)
            (l.visible ? l.close() : l.open());
    }
    function openPanel(map) {
        const l = focusedPanel(map);
        if (l)
            l.open();
    }
    function closePanel(map) {
        const l = focusedPanel(map);
        if (l)
            l.close();
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            root.qsRoot.launcherToggle();
        }
        function open(): void {
            root.qsRoot.launcherSet(true);
        }
        function close(): void {
            root.qsRoot.launcherSet(false);
        }
    }
    IpcHandler {
        target: "clips"
        function toggle(): void {
            root.qsRoot.clipsToggle();
        }
        function open(): void {
            root.qsRoot.clipsSet(true);
        }
        function close(): void {
            root.qsRoot.clipsSet(false);
        }
    }
    IpcHandler {
        target: "powermenu"

        function toggle(): void {
            root.qsRoot.panelToggle("powermenu");
        }
        function open(): void {
            root.qsRoot.panelSet("powermenu", true);
        }
        function close(): void {
            root.qsRoot.panelSet("powermenu", false);
        }

        function probe(): void {
            root.qsRoot.powerFlowRef.probeBlockers();
        }
        function blockers(): string {
            return root.qsRoot.powerFlowRef.blockersDump();
        }
    }

    IpcHandler {
        target: "settings"

        function toggle(): void {
            root.qsRoot.panelToggle("settings");
        }
        function open(): void {
            root.qsRoot.panelSet("settings", true);
        }
        function close(): void {
            root.qsRoot.panelSet("settings", false);
        }
    }

    IpcHandler {
        target: "calendar"

        function toggle(): void {
            root.qsRoot.panelToggle("calendar");
        }
        function open(): void {
            root.qsRoot.panelSet("calendar", true);
        }
        function close(): void {
            root.qsRoot.panelSet("calendar", false);
        }
    }
    IpcHandler {
        target: "weather"

        function open(): void {
            root.qsRoot.panelSet("weather", true);
        }
        function toggle(): void {
            root.qsRoot.panelToggle("weather");
        }
        function close(): void {
            root.qsRoot.panelSet("weather", false);
        }
        function edit(): void {
            root.qsRoot.weatherSetEdit(true);
        }
    }
    IpcHandler {
        target: "tray"

        function menu(): string {
            const r = root.focusedPanel(root.qsRoot.trayRowByScreen);
            if (!r)
                return "no-tray";
            return r.openMenu("") ? "opened" : "no-menu";
        }

        function menuOf(id: string): string {
            const r = root.focusedPanel(root.qsRoot.trayRowByScreen);
            if (!r)
                return "no-tray";
            return r.openMenu(id) ? "opened" : "not-found";
        }

        function next(): string {
            const r = root.focusedPanel(root.qsRoot.trayRowByScreen);
            if (!r)
                return "no-tray";
            return r.openNextMenu() ? "opened" : "no-menu";
        }

        function list(): string {
            const r = root.focusedPanel(root.qsRoot.trayRowByScreen);
            return r ? r.listItems() : "[]";
        }
    }

    IpcHandler {
        target: "notify"

        function toggle(): void {
            root.notifCenter.togglePanel(root.qsRoot.focusedScreenName());
        }
        function close(): void {
            root.notifCenter.closePanel();
        }

        function clear(): void {
            root.notifCenter.clearAll();
        }

        function state(): string {
            return JSON.stringify({
                tracked: root.notifCenter.openCount,
                maxTracked: root.notifCenter.maxTracked,
                maxVisible: root.notifCenter.maxVisible,
                history: root.notifCenter.history.length,
                historyLimit: root.notifCenter.historyLimit,
                unread: root.notifCenter.hasUnread,
                dnd: root.notifCenter.dnd,
                panel: root.notifCenter.panelOpen
            });
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
        function toggle(): void {
            if (!root.qsRoot.showWallpaper)
                root.qsRoot.setBarFlag("showWallpaper", true);
            root.qsRoot.panelToggle("wallpaper");
        }
        function open(): void {
            if (!root.qsRoot.showWallpaper)
                root.qsRoot.setBarFlag("showWallpaper", true);
            root.qsRoot.panelSet("wallpaper", true);
        }
        function close(): void {
            root.qsRoot.panelSet("wallpaper", false);
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
            root.qsRoot.cyclePalette();
            return Style.paletteName;
        }
        function set(name: string): string {
            root.qsRoot.setPaletteName(String(name));
            return Style.paletteName;
        }

        function colors(): string {
            return Style.paletteReport();
        }

        function scan(): string {
            return Style.paletteScanReport();
        }
    }
}
