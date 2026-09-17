pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Pil durumunun tek kaynağı. watchers/battery_wait.sh udevadm power_supply
// olayını bekler (10sn failsafe timeout'u kendi içinde), döndüğünde fetch koşar.
Item {
    id: root

    readonly property string watcherDir: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/core/watchers"

    // --- Public state ---
    property int percent: 100
    property string status: "Unknown"
    property string icon: "󰁹"
    property bool ready: false

    readonly property bool charging: status === "Charging" || status === "Full"

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
        command: ["bash", root.watcherDir + "/battery_fetch.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text ? this.text.trim() : "";
                if (txt !== "") {
                    try {
                        let d = JSON.parse(txt);
                        root.percent = parseInt(d.percent) || 0;
                        root.status = d.status;
                        root.icon = d.icon;
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
        command: ["bash", root.watcherDir + "/battery_wait.sh"]
        onExited: {
            if (root.subscribers > 0) {
                fetchProc.running = false;
                fetchProc.running = true;
            }
        }
    }
}
