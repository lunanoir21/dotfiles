pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    readonly property string watcherDir: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/core/watchers"

    // --- Centralized Properties ---
    property int cpu: 0
    property int ramPercent: 0
    property real ramGb: 0.0
    property int temp: 0
    property real netRx: 0
    property real netTx: 0
    
    // --- Lifecycle Management ---
    property int subscribers: 0
    
    function subscribe() { 
        subscribers++; 
        if (subscribers === 1) {
            fetchTimer.restart();
            fetchProc.running = true; // Fetch immediately on first open
        }
    }
    
    function unsubscribe() { 
        subscribers = Math.max(0, subscribers - 1); 
        if (subscribers === 0) {
            fetchTimer.stop();
            fetchProc.running = false;
        }
    }

    Timer {
        id: fetchTimer
        interval: 2000
        repeat: true
        running: false
        onTriggered: {
            fetchProc.running = false;
            fetchProc.running = true;
        }
    }

    Process {
        id: fetchProc
        running: false
        command: ["bash", root.watcherDir + "/sys_fetcher.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                let text = this.text ? this.text.trim() : "";
                if (!text) return;
                
                let p = text.split("|");
                if (p.length >= 6) {
                    root.cpu = parseInt(p[0]);
                    root.ramPercent = parseInt(p[1]);
                    root.ramGb = parseFloat(p[2]);
                    root.temp = parseInt(p[3]);
                    root.netRx = parseFloat(p[4]);
                    root.netTx = parseFloat(p[5]);
                }
            }
        }
    }
}
