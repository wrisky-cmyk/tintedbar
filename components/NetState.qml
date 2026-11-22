pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking

Item {
    id: root

    function modelValues(model) {
        return Compositor.modelValues(model);
    }

    function connectedWifi() {
        for (const d of root.modelValues(Networking.devices)) {
            if (!d || d.type !== DeviceType.Wifi || !d.connected)
                continue;
            for (const n of root.modelValues(d.networks)) {
                if (n && n.connected)
                    return n;
            }
        }
        return null;
    }

    function connectedWired() {
        for (const d of root.modelValues(Networking.devices)) {
            if (!d || d.type !== DeviceType.Wired)
                continue;
            if (d.connected)
                return d;
        }
        return null;
    }

    function wiredDevice() {
        for (const d of root.modelValues(Networking.devices)) {
            if (!d || d.type !== DeviceType.Wired || !d.nmManaged)
                continue;
            return d;
        }
        return null;
    }

    function wiredNetwork() {
        const d = root.wiredDevice();
        if (!d)
            return null;
        if (d.network)
            return d.network;
        for (const n of root.modelValues(d.networks))
            if (n)
                return n;
        return null;
    }

    function wifiDevice() {
        for (const d of root.modelValues(Networking.devices)) {
            if (!d || d.type !== DeviceType.Wifi || !d.nmManaged)
                continue;
            return d;
        }
        return null;
    }

    function netToggleWifiLink() {
        if (root.wifiDevice() === null)
            return JSON.stringify({
                acted: "nothing"
            });
        if (root.connectedWifi() !== null) {
            Networking.wifiEnabled = false;
            return JSON.stringify({
                acted: "wifi-radio",
                wifiEnabled: false,
                wifiHardware: Networking.wifiHardwareEnabled
            });
        }
        if (!Networking.wifiEnabled) {
            Networking.wifiEnabled = true;
            return JSON.stringify({
                acted: "wifi-radio",
                wifiEnabled: true,
                wifiHardware: Networking.wifiHardwareEnabled
            });
        }
        return JSON.stringify({
            acted: "nothing"
        });
    }

    function netToggleWiredLink() {
        const w = root.wiredDevice();
        if (w && w.connected) {
            w.disconnect();
            return JSON.stringify({
                acted: "wired-off",
                iface: String(w.name)
            });
        }

        const n = root.wiredNetwork();
        if (!n)
            return JSON.stringify({
                acted: "nothing"
            });
        n.connect();
        return JSON.stringify({
            acted: "wired-on",
            iface: w ? String(w.name) : null,
            net: String(n.name)
        });
    }

    function netToggleLink() {
        const w = root.wiredDevice();
        if (w && w.connected)
            return root.netToggleWiredLink();
        const hasWifi = root.wifiDevice() !== null;
        if (hasWifi && (root.connectedWifi() !== null || !Networking.wifiEnabled))
            return root.netToggleWifiLink();
        return JSON.stringify({
            acted: "nothing"
        });
    }

    function isTunnelIface(name) {
        return /^(tun|tap|wg|tailscale|zt|ppp|ipsec|nordlynx)/.test(String(name));
    }

    function netState() {
        const w = root.connectedWifi();
        const e = root.connectedWired();
        const dev = root.wiredDevice();
        const wifiDev = root.wifiDevice();
        return JSON.stringify({
            wifiEnabled: Networking.wifiEnabled,
            wifiHardware: Networking.wifiHardwareEnabled,
            wiredIface: dev ? String(dev.name) : null,
            wifiIface: wifiDev ? String(wifiDev.name) : null,
            wifi: w ? String(w.name) : null,
            wired: e ? String(e.name) : null,
            devices: root.modelValues(Networking.devices).map(d => d ? {
                    name: String(d.name),
                    type: DeviceType.toString(d.type),
                    managed: d.nmManaged,
                    connected: d.connected,
                    nets: root.modelValues(d.networks).map(n => n ? String(n.name) : null),
                    hasLink: d.hasLink,
                    hasNetworks: d.networks !== undefined,
                    isWiredEnum: d.type === DeviceType.Wired
                } : null)
        });
    }
}
