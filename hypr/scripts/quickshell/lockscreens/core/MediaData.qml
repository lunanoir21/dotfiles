import QtQuick
import Quickshell
import Quickshell.Io

// Kilit ekranları için görselsiz medya veri/kontrol kaynağı. playerctl'i
// saran mevcut music_info.sh betiğini periyodik olarak çalıştırıp JSON'ı
// ayrıştırır. TopBar.qml'deki dbus-monitor tabanlı anlık güncelleme yerine
// bilinçli olarak basit bir zamanlayıcı kullanıyor — kilit ekranı için
// 2 saniyelik gecikme fark edilmiyor ve sürekli bir dbus-monitor süreci
// açmaktan çok daha az risk taşıyor.
Item {
    id: root
    visible: false

    property string title: "Not Playing"
    property string artist: ""
    property string status: "Stopped"
    property string artUrl: ""
    property string timeStr: ""
    property real percent: 0

    readonly property bool hasPlayer: status === "Playing" || status === "Paused"
    readonly property bool isPlaying: status === "Playing"

    function playPause() { Quickshell.execDetached(["playerctl", "play-pause"]); refresh(); refreshTimer.start(); }
    function next()      { Quickshell.execDetached(["playerctl", "next"]);       refresh(); refreshTimer.start(); }
    function previous()  { Quickshell.execDetached(["playerctl", "previous"]);   refresh(); refreshTimer.start(); }
    function stop()      { Quickshell.execDetached(["playerctl", "stop"]);       refresh(); refreshTimer.start(); }
    function refresh()   { poller.running = false; poller.running = true; }

    // playerctl komutları D-Bus'a anında yansımayabiliyor; ilk poll'dan
    // kısa süre sonra ikinci bir poll ile durumu netleştiriyoruz.
    Timer { id: refreshTimer; interval: 300; onTriggered: root.refresh() }

    Process {
        id: poller
        command: ["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/widgets/music/music_info.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                const txt = this.text.trim();
                if (txt === "") return;
                try {
                    const d = JSON.parse(txt);
                    root.title   = d.title ?? "Not Playing";
                    root.artist  = d.artist ?? "";
                    root.status  = d.status ?? "Stopped";
                    root.artUrl  = d.artUrl ?? "";
                    root.timeStr = d.timeStr ?? "";
                    root.percent = Number(d.percent) || 0;
                } catch (e) {
                    console.warn("MediaData: music_info.sh çıktısı ayrıştırılamadı:", e);
                }
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
