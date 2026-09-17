//@ pragma UseQApplication
import QtQuick
import Quickshell
import "widgets"
import "vendor/dynamic-island" as DynamicIslandModule
import "vendor/quay" as QuayModule
import "vendor/flare/ui" as FlareModule

ShellRoot {
    Connections {
        target: Quickshell
        function onReloadCompleted() { Quickshell.inhibitReloadPopup() }
        function onReloadFailed(errorString) { Quickshell.inhibitReloadPopup() }
    }

    Main {}
    TopBar {}
    DynamicIslandModule.DynamicIslandHost {}
    QuayModule.QuayHost {}
    FlareModule.FlareHost {}
}
