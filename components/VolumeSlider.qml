import QtQuick
import Quickshell.Services.Pipewire

Item {
    id: volSlider

    required property var qsRoot

    readonly property var sink: Pipewire.defaultAudioSink

    readonly property var audio: (volSlider.sink && volSlider.sink.audio) ? volSlider.sink.audio : null

    implicitWidth: 80
    implicitHeight: Style.barContentHeight

    property real value: 0
    readonly property bool dragging: sliderArea.volDrag

    readonly property real shownValue: (volSlider.audio && volSlider.audio.muted) ? 0 : Math.min(1, Math.max(0, volSlider.value))

    PwObjectTracker {
        id: sinkTracker
        objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
    }

    function applyVolume(v) {
        v = Math.min(1, Math.max(0, v));
        if (!volSlider.audio) {
            if (Style.debug)
                console.log("[VOL] set volume but no audio sink");
            return;
        }

        volSlider.value = v;
        if (Style.debug)
            console.log("[VOL] set volume", v);
        volSlider.audio.volume = v;
        if (v > 0 && volSlider.audio.muted)
            volSlider.audio.muted = false;
    }

    onAudioChanged: {
        if (volSlider.audio && !volSlider.dragging)
            volSlider.value = Number(volSlider.audio.volume) || 0;
    }

    Connections {
        target: volSlider.audio
        function onVolumeChanged() {
            if (!volSlider.dragging)
                volSlider.value = Number(volSlider.audio.volume) || 0;
        }
    }

    Rectangle {
        id: trough
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 1
        width: parent.width
        height: 5
        radius: 5
        color: Style.trough

        Rectangle {

            width: parent.width * volSlider.shownValue
            height: parent.height
            radius: 5
            color: Style.fill
        }
    }

    MouseArea {
        id: sliderArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        acceptedButtons: Qt.LeftButton | Qt.RightButton

        property bool volDrag: false

        function setFromX(px) {
            volSlider.applyVolume(px / Math.max(1, sliderArea.width));
        }
        onPressed: m => {
            if (m.button !== Qt.LeftButton)
                return;
            sliderArea.volDrag = true;
            sliderArea.setFromX(m.x);
        }
        onReleased: m => {
            if (m.button === Qt.LeftButton)
                sliderArea.volDrag = false;
        }
        onCanceled: sliderArea.volDrag = false
        onPositionChanged: m => {
            if (sliderArea.volDrag)
                sliderArea.setFromX(m.x);
        }

        onClicked: m => {
            if (m.button === Qt.RightButton)
                qsRoot.audioToggleMute("right-click(slider)");
        }
    }

    WheelHandler {
        property real accum: 0
        onWheel: ev => {
            if (ev.angleDelta.y === 0)
                return;
            accum += ev.angleDelta.y;
            while (Math.abs(accum) >= 120) {
                const dir = accum > 0 ? 1 : -1;
                accum -= dir * 120;
                volSlider.applyVolume(volSlider.value + dir * 0.02);
            }
        }
    }

    Component.onCompleted: {
        if (volSlider.audio)
            volSlider.value = Number(volSlider.audio.volume) || 0;
        if (Style.debug) {
            console.log("[VOL] ready=" + Pipewire.ready + " sink=" + (volSlider.sink ? volSlider.sink.name : "null") + " audio=" + (volSlider.audio ? String(volSlider.audio.volume) : "null"));
        }
    }
}
