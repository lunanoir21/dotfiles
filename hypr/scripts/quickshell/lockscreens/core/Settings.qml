pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// settings.json'ın tek canlı okuyucusu.
//
// Daha önce üç ayrı yer (Main.qml, Scaler.qml, TopBar.qml) aynı dosya için
// kendi `inotifywait` + `cat` process çiftini açıyordu. Scaler on ayrı widget'ta
// örneklendiği için her açılan panel bir watcher daha ekliyordu.
// Burada FileView var: olay güdümlü ve sıfır process.
//
// Yazma tarafı Config.qml'de kalıyor; burası yalnızca okur.
Item {
    id: root

    property real uiScale: 1.0
    property int workspaceCount: 8

    function applySettings() {
        let text = "";
        try { text = view.text(); } catch (e) { return; }
        if (!text || text.trim() === "" || text.trim() === "{}") return;
        try {
            let parsed = JSON.parse(text);
            if (parsed.uiScale !== undefined) root.uiScale = parsed.uiScale;
            if (parsed.workspaceCount !== undefined) root.workspaceCount = parsed.workspaceCount;
        } catch (e) {}
    }

    FileView {
        id: view
        path: Quickshell.env("HOME") + "/.config/hypr/settings.json"
        watchChanges: true
        onLoaded: root.applySettings()
        onFileChanged: view.reload()
        onLoadFailed: error => {}
    }
}
