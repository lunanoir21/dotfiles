//@ pragma UseQApplication

import QtQuick
import Quickshell
import "../core"

// Renders offscreen and writes a PNG, so screenshots never open a window on
// the desktop. Run through tools/capture.sh.
ShellRoot {
    id: root

    readonly property string out: Quickshell.env("DEPOT_CAPTURE_OUT") || "/tmp/depot-capture.png"

    FloatingWindow {
        id: win
        implicitWidth: 400
        implicitHeight: 200
        color: DepotTheme.base

        Text {
            anchors.centerIn: parent
            text: "Depot capture"
            color: DepotTheme.text
            font.family: DepotTheme.display
            font.pixelSize: 40
        }
    }

    Timer {
        interval: 1500
        running: true
        onTriggered: win.contentItem.grabToImage(result => {
            console.log("depot-capture saved", result.saveToFile(root.out), root.out);
            Qt.quit();
        })
    }
}
