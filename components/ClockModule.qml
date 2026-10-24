import QtQuick

Module {
    id: clockModule

    required property var qsRoot
    required property var calendarPopup

    bgColor: "transparent"
    radius: 4
    padLeft: 5
    padRight: 5
    marginRight: 5
    contentYOffset: 1

    readonly property int clockPx: 16

    readonly property int clockGap: 6

    contentWidth: clockModule.alt ? clockWdMetrics.advanceWidth + clockDayMetrics.advanceWidth + clockTimeMetrics.advanceWidth + 2 * clockModule.clockGap : clockText.implicitWidth

    property bool alt: false

    property int clockTick: 0
    property string clockStr: {
        clockTick;
        return Style.timeStr(qsRoot.showClockSeconds, qsRoot.clock24);
    }

    readonly property var altParts: clockModule.alt ? (function () {
            const tick = clockModule.clockStr;
            return I18n.dateParts(qsRoot.showClockSeconds, qsRoot.clock24);
        })() : {
        wd: "",
        day: "",
        time: ""
    }

    TextMetrics {
        id: clockWdMetrics
        font.family: Style.nerd
        font.pixelSize: clockModule.clockPx
        text: I18n.dateSampleParts(qsRoot.showClockSeconds, qsRoot.clock24).wd
    }
    TextMetrics {
        id: clockDayMetrics
        font.family: Style.nerd
        font.pixelSize: clockModule.clockPx
        text: I18n.dateSampleParts(qsRoot.showClockSeconds, qsRoot.clock24).day
    }
    TextMetrics {
        id: clockTimeMetrics
        font.family: Style.nerd
        font.pixelSize: clockModule.clockPx

        text: I18n.dateSampleParts(qsRoot.showClockSeconds, qsRoot.clock24).time
    }

    Text {
        id: clockText
        anchors.centerIn: parent
        visible: !clockModule.alt
        text: clockModule.clockStr
        color: Style.text2
        font.family: Style.nerd
        font.pixelSize: clockModule.clockPx
    }

    Row {
        id: clockAltRow
        anchors.centerIn: parent
        visible: clockModule.alt
        spacing: clockModule.clockGap

        Text {
            id: clockAltWd
            text: clockModule.altParts.wd
            color: Style.text2
            font.family: Style.nerd
            font.pixelSize: clockModule.clockPx
        }
        Text {
            text: clockModule.altParts.day
            color: Style.text2
            font.family: Style.nerd
            font.pixelSize: clockModule.clockPx
            anchors.baseline: clockAltWd.baseline
        }
        Text {
            text: clockModule.altParts.time
            color: Style.text2
            font.family: Style.nerd
            font.pixelSize: clockModule.clockPx
            anchors.baseline: clockAltWd.baseline
        }
    }

    Timer {
        id: clockSecTick
        interval: 1000
        running: qsRoot.showClockSeconds
        repeat: true
        onTriggered: clockModule.clockTick++
    }
    Timer {
        id: clockMinTick
        interval: 60000
        running: !qsRoot.showClockSeconds
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            clockModule.clockTick++;

            const d = new Date();
            clockMinTick.interval = 60000 - (d.getSeconds() * 1000 + d.getMilliseconds()) + 30;
            clockMinTick.restart();
        }
    }

    onClicked: calendarPopup.toggle()
    onRightClicked: clockModule.alt = !clockModule.alt
}
