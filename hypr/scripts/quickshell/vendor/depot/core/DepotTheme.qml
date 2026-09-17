pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Monochrome, like Quay. Green is a detail color only: status dots, the
// installed mark, focus rings and the seal. Buttons and headings stay neutral.
Singleton {
    id: root

    // xdg-desktop-portal color-scheme: 1 prefers dark, 2 prefers light,
    // 0 has no preference and keeps black.
    property bool systemDark: true

    readonly property bool light: DepotStore.theme === "white"
        || (DepotStore.theme === "auto" && !root.systemDark)

    readonly property color base: root.light ? "#ffffff" : "#000000"
    readonly property color mantle: root.light ? "#f5f5f5" : "#0a0a0a"
    readonly property color surface0: root.light ? "#efefef" : "#121212"
    readonly property color surface1: root.light ? "#e2e2e2" : "#1c1c1c"
    readonly property color line: root.light ? "#e0e0e0" : "#222222"
    readonly property color overlay0: root.light ? "#8a8a8a" : "#6e6e6e"
    readonly property color subtext0: root.light ? "#4a4a4a" : "#a8a8a8"
    readonly property color text: root.light ? "#0a0a0a" : "#f5f5f5"

    // Filled buttons use the text color, not the accent.
    readonly property color primary: root.text
    readonly property color primaryInk: root.base

    readonly property color accent: root.light ? "#2f8f45" : "#5fd97a"
    readonly property color perforation: root.light ? "#cfcfcf" : "#3a3a3a"
    readonly property color tagFill: root.light ? "#ffffff" : "#121212"
    readonly property color tagStroke: root.light ? "#0a0a0a" : "#f5f5f5"

    readonly property color warning: root.light ? "#8a6100" : "#e3b341"
    readonly property color danger: root.light ? "#b3372b" : "#f07167"

    readonly property string display: displayFont.status === FontLoader.Ready ? displayFont.name : "sans-serif"
    readonly property string sans: sansFont.status === FontLoader.Ready ? sansFont.name : "sans-serif"
    readonly property string mono: monoRegular.status === FontLoader.Ready ? monoRegular.name : "monospace"

    readonly property int radiusLarge: 16
    readonly property int radiusMedium: 10
    readonly property int radiusSmall: 6

    function alpha(color, a) {
        return Qt.rgba(color.r, color.g, color.b, a);
    }

    FontLoader { id: displayFont; source: Qt.resolvedUrl("../assets/fonts/BigShouldersDisplay-Variable.ttf") }
    FontLoader { id: sansFont; source: Qt.resolvedUrl("../assets/fonts/IBMPlexSans-Variable.ttf") }
    FontLoader { id: monoRegular; source: Qt.resolvedUrl("../assets/fonts/IBMPlexMono-Regular.ttf") }
    FontLoader { source: Qt.resolvedUrl("../assets/fonts/IBMPlexMono-Medium.ttf") }
    FontLoader { source: Qt.resolvedUrl("../assets/fonts/IBMPlexMono-SemiBold.ttf") }

    function applyScheme(text) {
        let match = String(text || "").match(/uint32 (\d)/);
        if (match) root.systemDark = match[1] !== "2";
    }

    readonly property bool followingSystem: DepotStore.theme === "auto"

    Process {
        running: root.followingSystem
        command: ["gdbus", "call", "--session",
            "--dest", "org.freedesktop.portal.Desktop",
            "--object-path", "/org/freedesktop/portal/desktop",
            "--method", "org.freedesktop.portal.Settings.ReadOne",
            "org.freedesktop.appearance", "color-scheme"]
        stdout: StdioCollector {
            onStreamFinished: root.applyScheme(this.text)
        }
    }

    Process {
        running: root.followingSystem
        command: ["gdbus", "monitor", "--session",
            "--dest", "org.freedesktop.portal.Desktop",
            "--object-path", "/org/freedesktop/portal/desktop"]
        stdout: SplitParser {
            onRead: line => {
                if (line.indexOf("'org.freedesktop.appearance', 'color-scheme'") !== -1)
                    root.applyScheme(line);
            }
        }
    }
}
