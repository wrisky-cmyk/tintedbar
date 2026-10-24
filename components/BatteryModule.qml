import QtQuick
import Quickshell.Services.UPower

Module {
    id: batteryModule

    required property var qsRoot

    shown: qsRoot.showBattery && batteryModule.bat !== null

    bgColor: batteryModule.critical ? Style.danger : Style.bg
    opacityVal: batteryModule.critical ? (batteryModule.blinkOn ? 1.0 : 0.35) : 1.0
    radius: 5
    padLeft: 6
    padRight: 0
    marginRight: 0
    contentYOffset: 1
    contentWidth: batRow.implicitWidth

    readonly property var bat: Style.laptopBattery()
    readonly property real level: batteryModule.bat ? batteryModule.bat.percentage : 0

    readonly property string pctText: batteryModule.bat ? String(Math.round(batteryModule.bat.percentage * 100)) : ""

    readonly property string tag: !batteryModule.bat ? "" : (batteryModule.bat.state === UPowerDeviceState.Charging ? "\uF0E7" : (!UPower.onBattery ? "\uF1E6" : ""))
    readonly property bool critical: batteryModule.bat !== null && batteryModule.bat.percentage <= 0.15 && batteryModule.bat.state !== UPowerDeviceState.Charging && UPower.onBattery
    property bool blinkOn: false

    Timer {
        interval: 500
        repeat: true
        running: batteryModule.critical
        onTriggered: batteryModule.blinkOn = !batteryModule.blinkOn
    }

    Row {
        id: batRow
        spacing: 1
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
            id: batBody
            width: 34
            height: 16
            radius: 3
            color: "transparent"
            border.width: 1.5
            border.color: batteryModule.critical ? Style.danger : Style.text2

            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, Math.round((batBody.width - 4) * batteryModule.level))
                height: batBody.height - 5
                radius: 1
                color: batteryModule.critical ? Style.danger : Style.accent
                opacity: 0.45
            }

            Text {
                anchors.centerIn: parent
                text: batteryModule.pctText
                color: batteryModule.critical ? Style.text3 : Style.text1
                font.family: Style.nerd
                font.pixelSize: 11
            }
        }

        Rectangle {
            width: 2.5
            height: 7
            radius: 1
            anchors.verticalCenter: parent.verticalCenter
            color: batteryModule.critical ? Style.danger : Style.text2
        }

        Text {
            visible: batteryModule.tag !== ""
            text: batteryModule.tag
            color: batteryModule.critical ? Style.danger : Style.text2
            font.family: Style.nerd
            font.pixelSize: 13
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
