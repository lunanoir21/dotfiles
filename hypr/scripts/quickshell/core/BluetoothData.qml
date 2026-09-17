pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Bluetooth durumunun tek kaynağı. watchers/bt_wait.sh BlueZ'in
// PropertiesChanged D-Bus sinyalini dinler (Adapter1.Powered / Device1.Connected).
Item {
    id: root

    readonly property string watcherDir: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/core/watchers"

    // --- Public state ---
    property string status: "off"
    property string icon: "󰂲"
    property string connectedDevice: "Off"
    property bool ready: false

    readonly property bool powered: status.toLowerCase() === "on" || status.toLowerCase() === "enabled"

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
        command: ["bash", root.watcherDir + "/bt_fetch.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text ? this.text.trim() : "";
                if (txt !== "") {
                    try {
                        let d = JSON.parse(txt);
                        root.status = d.status;
                        root.icon = d.icon;
                        root.connectedDevice = d.connected;
                    } catch (e) {}
                }
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
        command: ["bash", root.watcherDir + "/bt_wait.sh"]
        onExited: {
            if (root.subscribers > 0) {
                fetchProc.running = false;
                fetchProc.running = true;
            }
        }
    }
}
