import QtQuick

Module {
    id: kbModule

    required property var qsRoot

    shown: qsRoot.showKeyboard && (kbModule.num || kbModule.caps)
    bgColor: "transparent"
    hoverTint: false
    radius: 0
    padLeft: 3
    padRight: 1
    marginRight: 0
    contentYOffset: 1
    contentWidth: kbRow.implicitWidth

    property bool num: false
    property bool caps: false

    Poller {
        active: qsRoot.showKeyboard
        interval: 3000
        command: ["sh", "-c", "n=0; c=0; s=; for k in numlock capslock; do v=; " + "for f in /sys/class/leds/*::$k/brightness; do " + "[ -e \"$f\" ] || break; read -r v < \"$f\"; break; done; " + "[ -n \"$v\" ] && s=1; " + "case $k in numlock) n=${v:-0};; capslock) c=${v:-0};; esac; done; " + "if [ -n \"$s\" ]; then printf 'led %s %s\\n' \"$n\" \"$c\"; " + (Style.compositor === "niri" ? "else printf 'led 0 0\\n'; fi" : "else exec hyprctl devices -j; fi")]
        onOutput: text => {
            const t = String(text).trim();

            if (t.indexOf("led ") === 0) {
                const p = t.split(/\s+/);
                kbModule.num = p[1] === "1";
                kbModule.caps = p[2] === "1";
                return;
            }

            try {
                const d = JSON.parse(t);
                let num = false, caps = false;
                for (const k of (d.keyboards || [])) {
                    if (k.numLock === true)
                        num = true;
                    if (k.capsLock === true)
                        caps = true;
                }
                kbModule.num = num;
                kbModule.caps = caps;
            } catch (e) {}
        }
    }

    Row {
        id: kbRow

        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        spacing: 3
        LockBadge {
            visible: kbModule.num
            label: "1"
        }
        LockBadge {
            visible: kbModule.caps
            label: "A"
        }
    }

    component LockBadge: Rectangle {
        property string label: ""
        width: 14
        height: 14
        radius: 2
        anchors.verticalCenter: parent.verticalCenter
        color: "transparent"
        border.width: 1
        border.color: Style.text1
        Text {
            anchors.centerIn: parent
            text: parent.label
            color: Style.text1
            font.family: Style.nerd
            font.bold: true
            font.pixelSize: 10
        }
    }
}
