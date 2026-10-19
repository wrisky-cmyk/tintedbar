import QtQuick
import Quickshell
import QtQuick.Effects
import "."

OverlayPanel {
    id: powerMenu

    readonly property string iconDir: Style.configDir + "/icons"

    function open() {
        visible = true;
    }
    function close() {
        visible = false;
    }
    function run(cmd) {
        close();
        Quickshell.execDetached(["bash", "-c", cmd]);
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.5)

        SafeMouseArea {
            anchors.fill: parent
            onClicked: powerMenu.close()
        }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: buttonRow.implicitWidth + 48
        height: 208
        radius: 16
        color: Style.card
        border.width: 1
        border.color: Style.border

        MouseArea {
            anchors.fill: parent
        }

        focus: true
        Keys.onEscapePressed: powerMenu.close()

        Keys.onPressed: event => {
            for (let i = 0; i < buttonRow.children.length; i++) {
                const b = buttonRow.children[i];
                if (b.modelData && b.modelData.key === event.text) {
                    powerMenu.run(b.modelData.cmd);
                    return;
                }
            }
        }

        Row {
            id: buttonRow
            anchors.centerIn: parent
            spacing: 24

            Repeater {

                model: [
                    {
                        icon: "lock.png",
                        labelKey: "power.lock",
                        key: "l",
                        cmd: "quickshell ipc call lock toggle"
                    },
                    {
                        icon: "logout.png",
                        labelKey: "power.logout",
                        key: "e",
                        cmd: "loginctl terminate-user $USER"
                    },
                    {
                        icon: "suspend.png",
                        labelKey: "power.suspend",
                        key: "u",
                        cmd: "systemctl suspend"
                    },
                    {
                        icon: "hibernate.png",
                        labelKey: "power.hibernate",
                        key: "h",
                        cmd: "systemctl hibernate"
                    },
                    {
                        icon: "shutdown.png",
                        labelKey: "power.shutdown",
                        key: "s",
                        cmd: "systemctl poweroff"
                    },
                    {
                        icon: "reboot.png",
                        labelKey: "power.reboot",
                        key: "r",
                        cmd: "systemctl reboot"
                    }
                ]

                delegate: Item {
                    id: btn
                    required property var modelData
                    width: 104
                    height: 144

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: btnMouse.containsMouse ? Style.hover : "transparent"
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 10

                        Item {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 60
                            height: 60

                            Image {
                                id: iconImg
                                anchors.fill: parent
                                source: "file://" + powerMenu.iconDir + "/" + btn.modelData.icon
                                fillMode: Image.PreserveAspectFit
                                mipmap: true
                                visible: false
                            }

                            MultiEffect {
                                anchors.fill: parent
                                source: iconImg
                                colorization: 1.0
                                colorizationColor: Style.text1
                                autoPaddingEnabled: false
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: I18n.t(btn.modelData.labelKey)
                            color: Style.text1
                            font.family: Style.cjk
                            font.pixelSize: 16
                        }
                    }

                    SafeMouseArea {
                        id: btnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: powerMenu.run(btn.modelData.cmd)
                    }
                }
            }
        }
    }
}
