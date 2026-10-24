import QtQuick
import Quickshell

Module {
    id: wifiModule

    required property var qsRoot

    shown: wifiModule.wifiPresent
    bgColor: "transparent"
    radius: 5
    padLeft: 3
    padRight: 0
    marginRight: 5
    contentYOffset: 1
    contentWidth: wifiRow.implicitWidth

    readonly property var wifi: Style.connectedWifi()

    readonly property bool wifiPresent: Style.wifiDevice() !== null

    Row {
        id: wifiRow
        anchors.centerIn: parent
        spacing: 5

        Canvas {
            id: wifiCanvas

            visible: wifiModule.wifi !== null
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            height: 18
            antialiasing: true
            contextType: "2d"

            property color ink: Style.text2
            onInkChanged: requestPaint()

            property int tier: {
                if (!wifiModule.wifi)
                    return 0;
                let s = Number(wifiModule.wifi.signalStrength) || 0;
                if (s < 1)
                    s *= 100;
                return s >= 75 ? 3 : s >= 50 ? 2 : s >= 25 ? 1 : 0;
            }

            onVisibleChanged: requestPaint()
            onTierChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.strokeStyle = ink;
                ctx.fillStyle = ink;
                ctx.lineWidth = 2;
                const cx = 9, cy = 14.4;
                const a0 = -Math.PI * 3 / 4, a1 = -Math.PI / 4;

                ctx.beginPath();
                ctx.arc(cx, cy, 1.5, 0, Math.PI * 2);
                ctx.fill();
                const radii = [4.3, 7.9, 11.5];
                for (let i = 0; i < 3; i++) {
                    ctx.globalAlpha = i < tier ? 1 : 0.35;
                    ctx.beginPath();
                    ctx.arc(cx, cy, radii[i], a0, a1);
                    ctx.stroke();
                }
                ctx.globalAlpha = 1;
            }
        }

        Text {
            id: wifiOffGlyph
            visible: wifiModule.wifi === null
            color: Style.text3
            font.family: Style.nerd
            font.pixelSize: 18
            text: "\u{F05AA}"
        }

        Text {
            id: wifiNameText
            visible: qsRoot.showNetIface && wifiModule.wifi !== null
            anchors.verticalCenter: parent.verticalCenter
            color: Style.text2
            font.family: Style.nerd
            font.pixelSize: 14
            width: Math.min(implicitWidth, 160)
            elide: Text.ElideRight
            text: wifiModule.wifi ? wifiModule.wifi.name : ""
        }
    }

    onClicked: Quickshell.execDetached(["nm-applet"])

    onRightClicked: qsRoot.netToggleWifi("right-click")
}
