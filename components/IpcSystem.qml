import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire

Item {
    id: root

    required property var qsRoot
    required property var lockScreen
    required property var polkitAgent
    required property var rebootNeeded

    IpcHandler {
        target: "lock"

        function lock(): void {
            root.lockScreen.lockNow();
        }
        function toggle(): void {
            root.lockScreen.lockNow();
        }
    }
    IpcHandler {
        target: "bt"

        function state(): string {
            return Style.btState();
        }

        function toggle(): string {
            return root.qsRoot.btToggle("ipc");
        }
    }
    IpcHandler {
        target: "audio"

        function state(): string {
            const sink = Pipewire.defaultAudioSink;
            const audio = (sink && sink.audio) ? sink.audio : null;
            return JSON.stringify({
                sink: sink ? String(sink.name) : null,
                volume: audio ? Math.round(audio.volume * 100) : null,
                muted: audio ? audio.muted : null
            });
        }

        function mute(): string {
            return root.qsRoot.audioToggleMute("ipc");
        }
    }
    IpcHandler {
        target: "brightness"

        function state(): string {
            return root.qsRoot.brightnessIpcState();
        }

        function set(p: int): string {
            if (!(p >= 0 && p <= 100)) {
                console.log("[BRIGHT] ipc set rejected, out of range: " + p);
                return JSON.stringify({
                    rejected: "out-of-range",
                    requested: p,
                    hint: "0..100"
                });
            }
            const m = root.qsRoot.panelForFocused(root.qsRoot.brightnessByScreen);
            if (m)
                m.setPct(p, "ipc");
            return root.qsRoot.brightnessIpcState();
        }
        function step(d: int): string {
            const m = root.qsRoot.panelForFocused(root.qsRoot.brightnessByScreen);

            if (!isFinite(d) || d === 0) {
                return JSON.stringify({
                    rejected: "bad-step",
                    requested: d
                });
            }
            if (m)
                m.stepPct(d, "ipc");
            return root.qsRoot.brightnessIpcState();
        }

        function preview(on: int): string {
            const m = root.qsRoot.panelForFocused(root.qsRoot.brightnessByScreen);
            if (m) {
                m.preview = on !== 0;
                if (m.preview && m.pct < 0)
                    m.pct = 42;
                if (Style.debug)
                    console.log("[BRIGHT] preview " + (m.preview ? "on" : "off"));
            }
            return root.qsRoot.brightnessIpcState();
        }
    }
    IpcHandler {
        target: "net"

        function state(): string {
            return Style.netState();
        }

        function toggle(): string {
            return root.qsRoot.netToggle("ipc");
        }

        function wifi(): string {
            return root.qsRoot.netToggleWifi("ipc");
        }

        function wired(): string {
            return root.qsRoot.netToggleWired("ipc");
        }
    }
    IpcHandler {
        target: "reboot"

        function state(): string {
            return JSON.stringify({
                needs: root.rebootNeeded.needs,
                needsReboot: root.rebootNeeded.needsReboot,
                needsRelogin: root.rebootNeeded.needsRelogin,
                count: root.rebootNeeded.count,
                kernel: root.rebootNeeded.newerKernel.length,
                modules: root.rebootNeeded.newerModules.length,
                libs: root.rebootNeeded.staleLibs.length,
                running: root.rebootNeeded.running,
                btime: root.rebootNeeded.btime,
                seenKernel: root.rebootNeeded.seenKernel,
                seenModules: root.rebootNeeded.seenModules,
                compositorPid: root.rebootNeeded.compositorPid,
                reason: root.rebootNeeded.reason,
                detailKernel: root.rebootNeeded.detailKernel,
                detailModules: root.rebootNeeded.detailModules,
                detailLibs: root.rebootNeeded.detailLibs,
                intervalMs: root.rebootNeeded.intervalMs
            });
        }

        function check(): string {
            root.rebootNeeded.kick();
            return "recheck triggered (sh async), see reboot state in 1s";
        }

        function notify(): string {
            root.qsRoot.notifyReboot("ipc");
            return JSON.stringify({
                needs: root.rebootNeeded.needs,
                count: root.rebootNeeded.count
            });
        }

        function preview(kernel: int, modules: int, libs: int): string {
            const detail = {
                kernel: kernel > 0 ? ["vmlinuz", "Image"] : [],
                modules: modules > 0 ? ["nvidia", "vboxdrv", "zfs"] : [],
                libs: libs > 0 ? ["libnvidia-glcore.so", "libnvidia-eglcore.so", "libc.so"] : []
            };
            return JSON.stringify(Object.assign(root.qsRoot.rebootNotice(kernel, modules, libs, detail), {
                action: root.qsRoot.rebootAction(kernel, modules)
            }));
        }

        function previewCurrent(): string {
            return JSON.stringify(Object.assign(root.qsRoot.rebootNotice(root.rebootNeeded.newerKernel.length, root.rebootNeeded.newerModules.length, root.rebootNeeded.staleLibs.length, root.rebootNeeded.noticeDetail), {
                action: root.qsRoot.rebootAction(root.rebootNeeded.newerKernel.length, root.rebootNeeded.newerModules.length)
            }));
        }
    }

    IpcHandler {
        target: "polkit"

        function state(): string {
            return root.qsRoot.polkitState();
        }

        function cancel(): void {
            if (root.polkitAgent.flow)
                root.polkitAgent.flow.cancelAuthenticationRequest();
        }
    }
}
