import QtQuick
import Quickshell.Io

Item {
    id: poller

    property bool active: true
    property int interval: 1000

    property int timeoutMs: 0

    property var command: []

    property string text: ""

    signal output(string text)
    signal started

    readonly property alias running: proc.running

    function kick() {
        if (proc.running)
            return false;
        poller.kickQueued = false;
        proc.running = true;
        return true;
    }

    function kickAfterExit() {
        if (!proc.running)
            return kick();
        poller.kickQueued = true;
        return true;
    }

    property bool kickQueued: false

    function stop() {
        poller.kickQueued = false;
        if (proc.running)
            proc.running = false;
    }

    Process {
        id: proc
        running: false
        command: poller.command
        onStarted: poller.started()
        onExited: {
            if (!poller.kickQueued)
                return;
            poller.kickQueued = false;

            if (!poller.active)
                return;
            Qt.callLater(poller.kick);
        }
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                poller.text = text;
                poller.output(text);
            }
        }
    }

    Timer {
        id: pollerWatchdog
        interval: Math.max(1000, poller.timeoutMs)
        repeat: false
        running: poller.timeoutMs > 0 && proc.running
        onTriggered: {
            if (!proc.running)
                return;
            console.warn("[POLLER] command timed out after " + poller.timeoutMs + "ms, killing");
            proc.running = false;
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
