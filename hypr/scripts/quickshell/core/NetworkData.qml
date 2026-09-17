pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Ağ durumunun tek kaynağı. watchers/network_wait.sh `nmcli monitor` çıktısını
// dinler, bağlantı değişiminde fetch koşar.
Item {
    id: root

    readonly property string watcherDir: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/core/watchers"

    // --- Public state ---
    property string status: "disabled"
    property string icon: "󰤮"
    property string ssid: ""
    property string ethStatus: "Disconnected"
    property bool ready: false

    readonly property bool wifiOn: status.toLowerCase() === "enabled" || status.toLowerCase() === "on"
    readonly property bool ethConnected: ethStatus === "Connected"

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
        command: ["bash", root.watcherDir + "/network_fetch.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text ? this.text.trim() : "";
                if (txt !== "") {
                    try {
                        let d = JSON.parse(txt);
                        root.status = d.status;
                        root.icon = d.icon;
                        root.ssid = d.ssid;
                        root.ethStatus = d.eth_status;
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
        command: ["bash", root.watcherDir + "/network_wait.sh"]
        onExited: {
            if (root.subscribers > 0) {
                fetchProc.running = false;
                fetchProc.running = true;
            }
        }
    }
}
