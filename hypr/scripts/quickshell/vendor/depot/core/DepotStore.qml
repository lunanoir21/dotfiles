pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Depot's own settings document. Never wired to a host shell's settings: a
// standalone install has only this.
Singleton {
    id: root

    readonly property string storeScript: root.localPath(Qt.resolvedUrl("../scripts/depot_store.sh"))

    readonly property string settingsPath: {
        let override = Quickshell.env("DEPOT_SETTINGS_FILE");
        if (override) return override;
        let base = Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config");
        return base + "/quickshell/depot/settings.json";
    }

    property string theme: "black"      // black | white | auto (follows the system)
    property string language: "auto"    // auto | en | tr

    readonly property var themes: ["black", "white", "auto"]
    readonly property var languages: ["auto", "en", "tr"]

    function localPath(url) {
        return decodeURIComponent(String(url).replace(/^file:\/\//, ""));
    }

    // The script reads as well as writes: it merges defaults over whatever is
    // on disk, so a fresh install and a hand-edited file arrive in one shape.
    Process {
        id: reader
        running: true
        command: ["bash", root.storeScript, "get"]
        stdout: StdioCollector {
            onStreamFinished: root.apply(String(this.text || ""))
        }
    }

    FileView {
        path: root.settingsPath
        printErrors: false
        watchChanges: true
        onFileChanged: reader.running = true
    }

    // A value outside the allowed set is dropped in favour of what is already
    // in memory, so a typo in a hand-edited file cannot break the window.
    function apply(raw) {
        let parsed;
        try {
            parsed = JSON.parse(raw.trim());
        } catch (e) {
            return;
        }
        let appearance = (parsed && parsed.appearance) || {};
        if (root.themes.indexOf(appearance.theme) !== -1) root.theme = appearance.theme;
        if (root.languages.indexOf(appearance.language) !== -1) root.language = appearance.language;
    }

    function setOption(path, value) {
        if (path === "appearance.theme") root.theme = value;
        if (path === "appearance.language") root.language = value;
        Quickshell.execDetached(["bash", root.storeScript, "set-option", path, JSON.stringify(value)]);
    }
}
