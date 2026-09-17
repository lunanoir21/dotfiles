pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Ses durumunun tek kaynağı. watchers/audio_wait.sh pactl olayını bekler,
// döndüğünde audio_fetch.sh bir kez çalışır — poll yok, olay güdümlü.
Item {
    id: root

    readonly property string watcherDir: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/core/watchers"

    // --- Public state ---
    property int volume: 0
    property string icon: "󰝟"
    property bool muted: false
    property bool ready: false

    // --- Ref-counted lifecycle (SysData ile aynı desen) ---
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
        command: ["bash", root.watcherDir + "/audio_fetch.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text ? this.text.trim() : "";
                if (txt !== "") {
                    try {
                        let d = JSON.parse(txt);
                        root.volume = parseInt(d.volume) || 0;
                        root.icon = d.icon;
                        root.muted = (d.is_muted === "true");
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
        command: ["bash", root.watcherDir + "/audio_wait.sh"]
        onExited: {
            if (root.subscribers > 0) {
                fetchProc.running = false;
                fetchProc.running = true;
            }
        }
    }
}
