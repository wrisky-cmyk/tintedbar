import QtQuick
import Quickshell.Io

Item {
    id: poller

    property bool active: true
    property int interval: 1000

    property var command: []

    property string text: ""

    signal output(string text)

    function kick() {
        if (!proc.running)
            proc.running = true;
    }

    Process {
        id: proc
        running: false
        command: poller.command
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                poller.text = text;
                poller.output(text);
            }
        }
    }

    Timer {

        interval: Math.max(200, poller.interval)
        repeat: true
        running: poller.active && Array.isArray(poller.command) && poller.command.length > 0

        triggeredOnStart: true

        onTriggered: if (!proc.running)
            proc.running = true
    }
}
