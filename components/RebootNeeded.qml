import QtQuick
import Quickshell
import Quickshell.Io
import "."

Item {
    id: rb

    property bool enabled: false
    readonly property int intervalMs: 5 * 60 * 1000

    property var newerKernel: []
    property var newerModules: []
    property var staleLibs: []
    property string running: ""
    property string btime: ""
    property int seenKernel: 0
    property int seenModules: 0
    property string compositorPid: ""

    property string reason: ""

    readonly property bool needsReboot: rb.newerKernel.length > 0 || rb.newerModules.length > 0
    readonly property bool needsRelogin: rb.staleLibs.length > 0
    readonly property bool needs: rb.needsReboot || rb.needsRelogin
    readonly property int count: rb.newerKernel.length + rb.newerModules.length + rb.staleLibs.length

    function fmtTime(sec) {
        return Qt.formatDateTime(new Date(sec * 1000), "MM-dd HH:mm");
    }
    readonly property string detailKernel: rb.newerKernel.map(e => e.path + "  " + rb.fmtTime(e.mtime)).join("\n")
    readonly property string detailModules: rb.newerModules.map(e => e.path + "  " + rb.fmtTime(e.mtime)).join("\n")
    readonly property string detailLibs: rb.staleLibs.join("\n")

    function baseName(path) {
        const s = String(path || "");
        const i = s.lastIndexOf("/");
        return i >= 0 ? s.substring(i + 1) : s;
    }
    function moduleName(path) {
        return rb.baseName(path).replace(/\.ko(\.(zst|xz|gz))?$/, "");
    }
    function libName(path) {
        return rb.baseName(path).replace(/(\.so)(\.[0-9].*)?$/, "$1");
    }
    function uniqueNames(names) {
        const out = [];
        for (const n of names)
            if (n && out.indexOf(n) < 0)
                out.push(n);
        return out;
    }
    readonly property var kernelNames: rb.newerKernel.map(e => rb.baseName(e.path))
    readonly property var moduleNames: rb.uniqueNames(rb.newerModules.map(e => rb.moduleName(e.path)))
    readonly property var libNames: rb.uniqueNames(rb.staleLibs.map(p => rb.libName(p)))
    readonly property var noticeDetail: ({
            kernel: rb.kernelNames,
            modules: rb.moduleNames,
            libs: rb.libNames
        })

    readonly property var checkCmd: ["sh", "-c", "bt=; while read -r k v; do if [ \"$k\" = btime ]; then bt=$v; break; fi; done < /proc/stat; " + "IFS= read -r rel < /proc/sys/kernel/osrelease 2>/dev/null || rel=; " + "printf 'RUNNING\\t%s\\nBTIME\\t%s\\n' \"$rel\" \"$bt\"; " + "find /boot -maxdepth 1 -type f " + "\\( -name 'vmlinuz*' -o -name 'vmlinux*' -o -name 'bzImage*' " + "-o -name 'Image*' -o -name 'zImage*' -o -name 'uImage*' -o -name 'kernel*.img' \\) " + "-printf 'IMG\\t%p\\t%T@\\n' 2>/dev/null; " + "md=/usr/lib/modules/$rel; " + "find \"$md/updates\" \"$md/extramodules\" \"$md/extra\" -type f -name '*.ko*' " + "-printf 'MOD\\t%p\\t%T@\\n' 2>/dev/null; " + "pid=; " + "if [ -n \"$HYPRLAND_INSTANCE_SIGNATURE\" ]; then " + "IFS= read -r pid < \"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/hyprland.lock\" " + "2>/dev/null || pid=; fi; " + "if [ -z \"$pid\" ] && [ -n \"$NIRI_SOCKET\" ]; then " + "s=${NIRI_SOCKET%.sock}; pid=${s##*.}; fi; " + "printf 'COMPOSITOR\\t%s\\n' \"$pid\"; " + "if [ -n \"$pid\" ] && [ -r \"/proc/$pid/maps\" ]; then " + "awk '$NF == \"(deleted)\" && $(NF-1) ~ /^\\/usr\\// { print \"LIB\\t\" $(NF-1) }' " + "\"/proc/$pid/maps\"; fi; " + "true"]

    function kick() {
        poller.kick();
    }

    function absorb(text) {
        const ker = [];
        const mod = [];
        const lib = [];
        let running = "";
        let bt = "";
        let pid = "";
        let seenK = 0;
        let seenM = 0;
        for (const line of String(text).split("\n")) {
            if (line === "")
                continue;
            const p = line.split("\t");
            if (p[0] === "RUNNING")
                running = p[1] || "";
            else if (p[0] === "BTIME")
                bt = p[1] || "";
            else if (p[0] === "COMPOSITOR")
                pid = p[1] || "";
            else if (p[0] === "IMG") {
                seenK++;
                ker.push({
                    path: p[1] || "",
                    mtime: parseFloat(p[2] || "0") || 0
                });
            } else if (p[0] === "MOD") {
                seenM++;
                mod.push({
                    path: p[1] || "",
                    mtime: parseFloat(p[2] || "0") || 0
                });
            } else if (p[0] === "LIB" && (p[1] || "") !== "") {
                if (lib.indexOf(p[1]) < 0)
                    lib.push(p[1]);
            }
        }

        const boot = parseFloat(bt) || 0;
        const newer = list => (boot > 0 ? list.filter(e => e.mtime > boot) : []);
        rb.running = running;
        rb.btime = bt;
        rb.compositorPid = pid;
        rb.seenKernel = seenK;
        rb.seenModules = seenM;
        rb.newerKernel = newer(ker);
        rb.newerModules = newer(mod);
        rb.staleLibs = lib;

        rb.reason = (boot > 0 ? "" : "couldn't read btime from /proc/stat (container or no perm?), none of ①②③ hold; ") + "① kernel images " + (seenK === 0 ? "none scanned (/boot unreadable?)" : seenK + " found") + "; ② third-party modules " + (seenM === 0 ? "none scanned (no dkms modules?)" : seenM + " found") + "; ③ " + (pid === "" ? "can't identify compositor (neither Hyprland nor niri?), skipped" : "checked maps of pid " + pid + ", deleted /usr files " + lib.length + " found");
    }

    Poller {
        id: poller
        active: rb.enabled
        interval: rb.intervalMs
        command: rb.checkCmd
        onOutput: text => rb.absorb(text)
    }
}
