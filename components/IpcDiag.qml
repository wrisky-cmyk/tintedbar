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

    IpcHandler {
        target: "icons"

        function audit(): string {
            const wins = root.iconAuditWindows();
            const miss = [];
            const pending = [];
            let ok = 0;
            for (const w of wins) {
                const cls = w.cls;
                if (!cls)
                    continue;
                const names = Style.appIconNames(cls);
                const ti = Style.titleIcon(w.title, cls);
                const all = ti ? [ti].concat(names) : names;
                const key = JSON.stringify(all);
                const cached = IconProbe.iconCacheGet(key);
                if (cached === undefined) {
                    IconProbe.requestIconProbe(key, all);
                    pending.push({
                        class: cls,
                        chain: all
                    });
                } else if (cached === "") {
                    miss.push({
                        class: cls,
                        title: w.title,
                        chain: all,
                        hint: root.iconAuditHint(names)
                    });
                } else {
                    ok++;
                }
            }
            return JSON.stringify({
                total: wins.length,
                ok: ok,
                missing: miss,
                pending: pending,
                summary: miss.length === 0 ? (pending.length > 0 ? "全部命中(另有 " + pending.length + " 个首次探测中, 稍后重查)" : "全部命中") : miss.length + " 个窗口解析不出图标"
            });
        }

        function list(): string {
            return root.iconAuditWindows().map(w => w.cls).join("\n");
        }
    }

    function iconAuditWindows() {
        const out = [];
        const c = Compositor.name;
        if (c === "niri") {
            for (const w of Compositor.niriWindows)
                out.push({
                    cls: String(w.obj.class || ""),
                    title: String(w.obj.title || "")
                });
            return out;
        }
        if (c === "sway") {
            for (const w of Compositor.swayWindows)
                out.push({
                    cls: String(w.obj.class || ""),
                    title: String(w.obj.title || "")
                });
            return out;
        }

        for (const pair of Compositor.toplevelSnapshot().sentinels) {
            const t = pair.toplevel;
            if (!t)
                continue;
            out.push({
                cls: Compositor.toplevelClass(t),
                title: String(t.title || "")
            });
        }
        return out;
    }

    function iconAuditHint(names) {
        const lc = String(names.length > 0 ? names[0] : "").toLowerCase();
        const hints = [];
        for (const n of names) {
            if (n !== lc && n.toLowerCase() === lc && n !== n.toLowerCase())
                hints.push("候选 '" + n + "' 含大写, 主题文件名通常全小写");
        }
        const e = Style.appForClass(String(names.length > 0 ? names[0] : ""));
        if (e && e.icon && names.indexOf(String(e.icon)) < 0)
            hints.push(".desktop 的 Icon=" + e.icon + " 不在候选链里");
        if (hints.length === 0)
            hints.push("无候选命中, 考虑加 classAliases");
        return hints.join("; ");
    }
}
