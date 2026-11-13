import QtQuick
import "."

Poller {
    id: capsPoller

    property bool capsOn: false
    active: false
    interval: 3000
    command: ["sh", "-c", "v=; s=; for f in /sys/class/leds/*::capslock/brightness; do " + "[ -e \"$f\" ] || break; read -r b < \"$f\" 2>/dev/null; " + "[ -n \"$b\" ] || break; s=1; [ \"$b\" != 0 ] && v=1; done; " + "if [ -n \"$s\" ]; then printf 'led %s\\n' \"${v:-0}\"; " + (Style.compositor === "niri" ? "else printf 'led 0\\n'; fi" : "else exec hyprctl devices -j; fi")]
    onOutput: text => {
        const t = String(text).trim();

        if (t.indexOf("led ") === 0) {
            capsPoller.capsOn = t.split(/\s+/)[1] === "1";
            return;
        }

        try {
            const d = JSON.parse(t);
            let caps = false;
            for (const k of (d.keyboards || []))
                if (k.capsLock === true)
                    caps = true;
            capsPoller.capsOn = caps;
        } catch (e) {}
    }
}
