import QtQuick
import "../core"

// Every installed app in one list, each row carrying its own Remove button —
// the "Installed" tab from GNOME Software / KDE Discover.
Column {
    id: root

    property string armedPackage: ""
    readonly property var installedEntries: DepotBackend.featured.filter(e => e.installed === true)

    signal installRequested(string packageName, string source, string name)
    signal removeRequested(string packageName, string name)
    signal opened(var entry)

    spacing: 2

    Repeater {
        model: root.installedEntries

        DepotPackageRow {
            required property var modelData
            width: root.width
            entry: modelData
            armedPackage: root.armedPackage
            onInstallRequested: (packageName, source, name) => root.installRequested(packageName, source, name)
            onRemoveRequested: (packageName, name) => root.removeRequested(packageName, name)
        }
    }

    Column {
        width: parent.width
        visible: root.installedEntries.length === 0
        topPadding: 40
        spacing: 6

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: DepotStrings.t("noInstalled")
            color: DepotTheme.text
            font.family: DepotTheme.sans
            font.pixelSize: 15
            font.weight: Font.Medium
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: DepotStrings.t("noInstalledHint")
            color: DepotTheme.subtext0
            font.family: DepotTheme.sans
            font.pixelSize: 13
        }
    }
}
