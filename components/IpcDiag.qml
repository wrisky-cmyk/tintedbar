import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    required property var qsRoot
    required property var screenPanels

    IpcHandler {
        target: "debug"

        function on(): string {
            Style.debug = true;
            Compositor.debug = true;
            return JSON.stringify({
                debug: true,
                compositor: true
            });
        }
        function off(): string {
            Style.debug = false;
            Compositor.debug = false;
            return JSON.stringify({
                debug: false,
                compositor: false
            });
        }
        function state(): string {
            return JSON.stringify({
                debug: Style.debug,
                compositor: Compositor.debug
            });
        }
    }

    IpcHandler {
        target: "registry"

        function dump(): string {
            return JSON.stringify({
                focused: root.qsRoot.focusedScreenName(),
                screens: Quickshell.screens.map(s => String(s.name)),
                roles: root.screenPanels.snapshot()
            });
        }
    }
}
