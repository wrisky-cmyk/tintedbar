import QtQuick
import Quickshell

PopupWindow {
    id: calendarPopup

    required property var qsRoot
    required property var panel
    required property var clockModule

    visible: false
    color: "transparent"

    function open() {
        const now = new Date();
        calendarPopup.today = now;
        calendarPopup.viewYear = now.getFullYear();
        calendarPopup.viewMonth = now.getMonth();
        calendarPopup.visible = true;
    }
    function close() {
        calendarPopup.visible = false;
    }
    function toggle() {
        calendarPopup.visible ? calendarPopup.close() : calendarPopup.open();
    }

    function shiftMonth(d) {
        let m = calendarPopup.viewMonth + d;
        let y = calendarPopup.viewYear;
        while (m < 0) {
            m += 12;
            y--;
        }
        while (m > 11) {
            m -= 12;
            y++;
        }
        calendarPopup.viewMonth = m;
        calendarPopup.viewYear = y;
    }

    implicitWidth: 350

    implicitHeight: calCol.implicitHeight + 20 + Style.barHeight + 2 - Style.barInset
    grabFocus: true

    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()

    property date today: new Date()

    property bool showLunar: qsRoot.showLunar

    readonly property real cellW: (calendarPopup.width - 20) / 7

    readonly property int gridRows: Math.ceil((calendarPopup.firstOffset() + calendarPopup.daysInMonth()) / 7)

    anchor.window: panel
    anchor.item: clockModule
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Top

    function firstOffset() {
        const d = new Date(calendarPopup.viewYear, calendarPopup.viewMonth, 1);
        return (d.getDay() + 6) % 7;
    }

    function daysInMonth() {
        return new Date(calendarPopup.viewYear, calendarPopup.viewMonth + 1, 0).getDate();
    }

    function cellDay(i) {
        const day = i - calendarPopup.firstOffset() + 1;
        if (day < 1 || day > calendarPopup.daysInMonth())
            return 0;
        return day;
    }

    function cellDate(i) {
        const day = calendarPopup.cellDay(i);
        if (day === 0)
            return null;
        return new Date(calendarPopup.viewYear, calendarPopup.viewMonth, day);
    }

    function isToday(day) {
        const t = calendarPopup.today;
        return day === t.getDate() && calendarPopup.viewYear === t.getFullYear() && calendarPopup.viewMonth === t.getMonth();
    }

    function isWeekend(i) {
        return (i % 7) >= 5;
    }

    Rectangle {
        id: calRect
        anchors.fill: parent

        anchors.topMargin: Style.barHeight + 2 - Style.barInset
        radius: 12
        color: Style.card
        border.width: 1
        border.color: Style.border

        focus: true
        Keys.onEscapePressed: calendarPopup.close()

        Keys.onLeftPressed: calendarPopup.shiftMonth(-1)
        Keys.onRightPressed: calendarPopup.shiftMonth(1)

        Column {
            id: calCol
            anchors.fill: parent
            anchors.margins: 10
            spacing: 6

            Item {
                width: parent.width
                height: 30

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "‹"
                    color: Style.text3
                    font.family: Style.cjk
                    font.pixelSize: 22

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: calendarPopup.shiftMonth(-1)
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.calendarTitle(calendarPopup.viewYear, calendarPopup.viewMonth)
                    color: Style.text1
                    font.family: Style.cjk
                    font.pixelSize: 19
                    font.weight: Font.Bold
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "›"
                    color: Style.text3
                    font.family: Style.cjk
                    font.pixelSize: 22

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: calendarPopup.shiftMonth(1)
                    }
                }
            }

            Row {
                width: parent.width
                spacing: 0

                Repeater {

                    model: I18n.weekdayHeaders
                    delegate: Text {
                        width: calendarPopup.cellW
                        height: 24
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: modelData
                        color: Style.accent
                        font.family: Style.cjk
                        font.pixelSize: 16
                    }
                }
            }

            Grid {
                width: parent.width
                columns: 7
                spacing: 0

                Repeater {

                    model: calendarPopup.gridRows * 7

                    delegate: Item {
                        width: calendarPopup.cellW
                        height: 48
                        readonly property int dayNum: calendarPopup.cellDay(index)

                        readonly property var mark: calendarPopup.showLunar ? I18n.dayMark(calendarPopup.cellDate(index)) : {
                            text: "",
                            kind: ""
                        }

                        Rectangle {
                            visible: calendarPopup.isToday(parent.dayNum)
                            width: 26
                            height: 26
                            radius: 12
                            color: "transparent"
                            border.width: 1.5
                            border.color: Style.accent
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: calDayText.verticalCenter
                        }

                        Text {
                            id: calDayText
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: 4
                            text: parent.dayNum || ""
                            visible: parent.dayNum !== 0
                            color: calendarPopup.isToday(parent.dayNum) ? Style.accent : (calendarPopup.isWeekend(index) ? Style.text3 : Style.text2)
                            font.family: Style.cjk
                            font.pixelSize: 16
                            font.weight: calendarPopup.isToday(parent.dayNum) ? Font.Bold : Font.Normal
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: calDayText.bottom
                            anchors.topMargin: 1
                            visible: text !== ""
                            text: (calendarPopup.showLunar && parent.dayNum !== 0) ? parent.mark.text : ""
                            color: parent.mark.kind === "lunar" ? Style.text3 : Style.accent
                            font.family: Style.cjk
                            font.pixelSize: 12
                        }
                    }
                }
            }

            Item {
                id: almanacBlock
                width: parent.width

                readonly property var info: calendarPopup.showLunar ? I18n.almanacToday(calendarPopup.today) : null
                visible: info !== null
                height: info !== null ? almCol.implicitHeight : 0

                Column {
                    id: almCol
                    width: parent.width
                    spacing: 5

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Style.border
                        opacity: 0.4
                    }

                    Item {
                        width: parent.width
                        height: 30

                        Row {
                            id: almMoon
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            Text {
                                height: 30
                                verticalAlignment: Text.AlignVCenter
                                color: Style.accent
                                font.family: Style.nerd
                                font.pixelSize: 26
                                text: almanacBlock.info ? almanacBlock.info.moonGlyph : ""
                            }
                            Text {
                                height: 30
                                verticalAlignment: Text.AlignVCenter
                                color: Style.text3
                                font.family: Style.cjk
                                font.pixelSize: 12
                                text: almanacBlock.info ? almanacBlock.info.moon : ""
                            }
                        }

                        Row {
                            id: almTail
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            Text {
                                height: 30
                                verticalAlignment: Text.AlignVCenter
                                color: Style.text3
                                font.family: Style.cjk
                                font.pixelSize: 12
                                text: almanacBlock.info ? almanacBlock.info.gzDay : ""
                            }
                            Text {
                                height: 30
                                verticalAlignment: Text.AlignVCenter
                                color: Style.accent
                                font.family: Style.cjk
                                font.pixelSize: 12
                                text: almanacBlock.info ? almanacBlock.info.term : ""
                            }
                        }

                        Text {
                            anchors.left: almMoon.right
                            anchors.leftMargin: 12
                            anchors.right: almTail.left
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            color: Style.text2
                            font.family: Style.cjk
                            font.pixelSize: 12
                            text: almanacBlock.info ? almanacBlock.info.lunar + " · " + almanacBlock.info.gzYear : ""
                        }
                    }
                }
            }
        }
    }
}
