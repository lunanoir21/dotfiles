import QtQuick
import Quickshell
import Quickshell.Io
import "ui"

// Integration point: the window plus the IPC surface a compositor keybind or
// a host shell can call into.
Scope {
    id: host

    property bool openOnStart: false
    // Standalone, closing the window ends Depot; vendored, it only hides.
    property bool quitOnClose: false

    DepotWindow {
        id: window
        visible: host.openOnStart

        // `closed` also fires while the window is first being set up, so only
        // a window that has actually been on screen counts as closed.
        property bool wasShown: false
        onBackingWindowVisibleChanged: if (window.backingWindowVisible) window.wasShown = true

        onClosed: {
            console.log("depot: closed, wasShown =", window.wasShown);
            if (!window.wasShown) return;
            if (host.quitOnClose) Qt.quit();
            else window.visible = false;
        }
    }

    IpcHandler {
        target: "depot"

        function open(): void { window.visible = true }
        function close(): void { window.visible = false }
        function toggle(): void { window.visible = !window.visible }
        function search(query: string): void {
            window.visible = true;
            window.setQuery(query);
        }
    }
}
