pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Klavye layout'unun tek kaynağı. watchers/kb_wait.sh Hyprland'in .socket2
// akışındaki activelayout>> olayını dinler.
Item {
    id: root

    readonly property string watcherDir: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/core/watchers"

    // --- Public state ---
    property string layout: "US"
    property bool ready: false

    // --- Ref-counted lifecycle ---
    property int subscribers: 0

    function subscribe() {
        subscribers++;
        if (subscribers === 1) fetchProc.running = true;
    }

    function unsubscribe() {
        subscribers = Math.max(0, subscribers - 1);
        if (subscribers === 0) {
            waitProc.running = false;
            fetchProc.running = false;
        }
    }

    Process {
        id: fetchProc
        command: ["bash", root.watcherDir + "/kb_fetch.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text ? this.text.trim() : "";
                if (txt !== "") root.layout = txt;
                root.ready = true;
                if (root.subscribers > 0) {
                    waitProc.running = false;
                    waitProc.running = true;
                }
            }
        }
    }

    Process {
        id: waitProc
        command: ["bash", root.watcherDir + "/kb_wait.sh"]
        onExited: {
            if (root.subscribers > 0) {
                fetchProc.running = false;
                fetchProc.running = true;
            }
        }
    }
}
