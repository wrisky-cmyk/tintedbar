pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io

Item {
    id: root

    function modelValues(model) {
        return Compositor.modelValues(model);
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

    function connectedBtDevice() {
        const a = root.btAdapter();
        if (!a)
            return null;
        for (const d of root.modelValues(a.devices))
            if (d && d.connected)
                return d;
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
        timeoutMs: 8000

        interval: (root.btAdapter() !== null || root.btProbeKnown) ? 15000 : 60000
        command: ["busctl", "--system", "get-property", "org.bluez", root.btAdapter() ? String(root.btAdapter().dbusPath) : "/org/bluez/hci0", "org.bluez.Adapter1", "Powered"]
        onOutput: text => {
            const t = String(text).trim();

            if (t.indexOf("b ") !== 0) {
                if (!root.btProbeLogged) {
                    root.btProbeLogged = true;
                    console.warn("[BT] busctl probe returned no parseable value; keeping last state");
                }
                return;
            }

            const wantOpen = root.btWantOpen;
            root.btProbeKnown = true;
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
}
