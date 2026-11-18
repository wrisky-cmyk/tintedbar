import QtQuick
import Quickshell

PopupWindow {
    id: weatherPopup

    required property var qsRoot
    required property var panel
    required property var weather
    required property var weatherModule

    visible: false
    function open() {
        if (qsRoot.showWeather && weather.ready)
            weatherPopup.visible = true;
    }
    function close() {
        weatherPopup.visible = false;
    }
    function toggle() {
        weatherPopup.visible ? weatherPopup.close() : weatherPopup.open();
    }

    Connections {
        target: weather
        function onReadyChanged() {
            if (!weather.ready)
                weatherPopup.close();
        }
    }

    readonly property string updatedText: {
        const ms = Number(weather.fetchedAt) || 0;
        if (ms <= 0)
            return "";
        const d = new Date(ms);
        const now = new Date();
        const yest = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1);
        const sameDay = (a, b) => a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
        let stamp;
        if (sameDay(d, now))
            stamp = Qt.formatTime(d, "HH:mm");
        else if (sameDay(d, yest))
            stamp = I18n.fill(I18n.t("wx.yesterdayAt"), {
                t: Qt.formatTime(d, "HH:mm")
            });
        else
            stamp = Qt.formatDateTime(d, "MM-dd HH:mm");
        if (weather.stale)
            stamp += " · " + I18n.t("wx.stale");
        return I18n.fill(I18n.t("wx.updated"), {
            t: stamp
        });
    }

    color: "transparent"

    implicitWidth: 244

    implicitHeight: wxCol.implicitHeight + 20 + Style.barHeight + 2 - Style.barInset
    grabFocus: true

    anchor.window: panel
    anchor.item: weatherModule
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Top

    Rectangle {
        id: wxCard
        anchors.fill: parent

        anchors.topMargin: Style.barHeight + 2 - Style.barInset
        radius: 12
        color: Style.card
        border.width: 1
        border.color: Style.border
        focus: true
        Keys.onEscapePressed: weatherPopup.close()

        Column {
            id: wxCol
            anchors.fill: parent
            anchors.margins: 10
            spacing: 6

            Item {
                width: parent.width

                height: 40

                Text {
                    id: wxNowGlyph
                    anchors.left: parent.left
                    anchors.top: parent.top
                    color: Style.accent
                    font.family: Style.nerd
                    font.pixelSize: 30
                    text: weather.current ? weather.glyph(weather.current.code, weather.current.isDay) : ""
                }
                Text {
                    id: wxNowTemp
                    anchors.left: wxNowGlyph.right
                    anchors.leftMargin: 8

                    anchors.verticalCenter: parent.verticalCenter
                    color: Style.text1
                    font.family: Style.nerd
                    font.pixelSize: 22
                    font.bold: true
                    text: weather.current ? Math.round(weather.current.temp) + "°" : ""
                }
                Text {
                    anchors.left: wxNowTemp.right
                    anchors.leftMargin: 8
                    anchors.right: parent.right
                    anchors.baseline: wxNowTemp.baseline
                    elide: Text.ElideRight
                    color: Style.text2
                    font.family: Style.cjk
                    font.pixelSize: 13

                    text: weather.current ? I18n.t("wx.c." + weather.wmoKey(weather.current.code)) : ""
                }
            }

            Text {
                width: parent.width
                elide: Text.ElideRight
                color: Style.text3
                font.family: Style.cjk

                font.pixelSize: 13
                text: weather.current ? I18n.t("wx.feels") + " " + Math.round(weather.current.feels) + "°  " + I18n.t("wx.humidity") + " " + Math.round(weather.current.humidity) + "%  " + I18n.t("wx.wind") + " " + Math.round(weather.current.wind) + " km/h" : ""
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Style.border
                opacity: 0.4
            }

            Repeater {
                model: weather.daily

                delegate: Item {
                    required property var modelData
                    required property int index
                    width: parent ? parent.width : 0
                    height: 24

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 52
                        elide: Text.ElideRight
                        color: Style.text2
                        font.family: Style.cjk
                        font.pixelSize: 13
                        text: index === 0 ? I18n.t("wx.today") : (index === 1 ? I18n.t("wx.tomorrow") : I18n.weekdayShort(weather.dayDate(modelData.date)))
                    }
                    Text {
                        id: wxDayGlyph
                        anchors.left: parent.left
                        anchors.leftMargin: 56
                        anchors.verticalCenter: parent.verticalCenter
                        color: Style.text3
                        font.family: Style.nerd
                        font.pixelSize: 15
                        text: weather.glyph(modelData.code, true)
                    }
                    Text {
                        id: wxDayRange
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        color: Style.text2
                        font.family: Style.nerd
                        font.pixelSize: 13
                        text: Math.round(modelData.min) + " / " + Math.round(modelData.max) + "°"
                    }

                    Text {
                        anchors.left: wxDayGlyph.right
                        anchors.leftMargin: 8
                        anchors.right: wxDayRange.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter

                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        color: Style.text3
                        font.family: Style.cjk
                        font.pixelSize: 12
                        text: I18n.t("wx.c." + weather.wmoKey(modelData.code))
                    }
                }
            }

            Item {
                width: parent.width
                height: 18

                Text {
                    anchors.left: parent.left
                    anchors.right: refreshLabel.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter

                    color: weather.stale ? Style.danger : Style.text3
                    font.family: Style.cjk
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    text: weatherPopup.updatedText
                }

                Text {
                    id: refreshLabel
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter

                    color: refreshMouse.containsMouse ? Style.accent : Style.text3
                    font.family: Style.cjk
                    font.pixelSize: 11
                    text: weather.refreshing ? I18n.t("wx.refreshing") : I18n.t("wx.refresh")
                }

                MouseArea {
                    id: refreshMouse
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter

                    width: refreshLabel.width
                    height: parent.height
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: weather.refresh()
                }
            }
        }
    }
}
