import QtQuick
import "../core"

// One app or package. Catalog entries and search results share this row;
// catalog entries carry `package` and a localized description.
Rectangle {
    id: root

    property var entry: ({})
    property string armedPackage: ""

    signal installRequested(string packageName, string source, string name)
    signal removeRequested(string packageName, string name)

    readonly property string packageName: root.entry.package || root.entry.name || ""
    readonly property string title: root.entry.name || root.packageName
    readonly property string description: DepotStrings.pick(root.entry.description)
    readonly property bool isAur: root.entry.source === "aur"
    readonly property bool installed: root.entry.installed === true
    readonly property bool available: root.entry.available !== false && root.packageName !== ""
    readonly property bool rowBusy: DepotBackend.busyPackage !== "" && DepotBackend.busyPackage === root.packageName
    readonly property bool armed: root.armedPackage !== "" && root.armedPackage === root.packageName
    readonly property string sourceLabel: root.isAur ? "aur" : (root.entry.repo || "")
    // Catalog entries have a display name, so their package name is extra detail.
    readonly property bool showPackageName: root.entry.package !== undefined && root.packageName !== root.title.toLowerCase()

    implicitHeight: 72
    radius: DepotTheme.radiusMedium
    color: hover.hovered ? DepotTheme.surface0 : "transparent"

    Behavior on color { ColorAnimation { duration: 100 } }

    HoverHandler { id: hover }

    DepotAppIcon {
        id: icon
        size: 40
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        iconName: root.entry.icon || root.packageName
        label: root.title
    }

    Column {
        anchors.left: icon.right
        anchors.leftMargin: 14
        anchors.right: actions.left
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Row {
            width: parent.width
            spacing: 8

            Text {
                id: nameText
                text: root.title
                color: root.available ? DepotTheme.text : DepotTheme.overlay0
                font.family: DepotTheme.sans
                font.pixelSize: 15
                font.weight: Font.Medium
                elide: Text.ElideRight
                width: Math.min(implicitWidth, parent.width - meta.width - (installedMark.visible ? installedMark.width + 8 : 0) - 8)
            }

            Text {
                id: meta
                anchors.baseline: nameText.baseline
                text: {
                    let parts = [];
                    if (root.showPackageName) parts.push(root.packageName);
                    if (root.sourceLabel) parts.push(root.sourceLabel);
                    if (root.entry.version) parts.push(root.entry.version);
                    return parts.join(" · ");
                }
                color: DepotTheme.overlay0
                font.family: DepotTheme.mono
                font.pixelSize: 11
                elide: Text.ElideRight
                width: Math.min(implicitWidth, parent.width * 0.55)
            }

            Row {
                id: installedMark
                visible: root.installed
                anchors.verticalCenter: nameText.verticalCenter
                spacing: 5

                Rectangle {
                    width: 6
                    height: 6
                    radius: 3
                    anchors.verticalCenter: parent.verticalCenter
                    color: DepotTheme.accent
                }
                Text {
                    text: DepotStrings.t("installed")
                    color: DepotTheme.subtext0
                    font.family: DepotTheme.sans
                    font.pixelSize: 11
                }
            }
        }

        Text {
            width: parent.width
            text: {
                if (!root.available) return root.isAur ? DepotStrings.t("needsHelper") : DepotStrings.t("unavailable");
                return root.description || " ";
            }
            color: DepotTheme.subtext0
            font.family: DepotTheme.sans
            font.pixelSize: 13
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }

    Item {
        id: actions
        width: button.implicitWidth
        height: button.implicitHeight
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter

        DepotButton {
            id: button
            anchors.fill: parent
            enabled: root.available && (!DepotBackend.busy || root.rowBusy)
            busy: root.rowBusy
            variant: root.armed ? "danger" : (root.installed ? "outline" : "filled")
            text: {
                if (root.rowBusy) return DepotStrings.t(DepotBackend.busyAction === "remove" ? "removing" : "installing");
                if (root.armed) return DepotStrings.t("confirmRemove");
                return DepotStrings.t(root.installed ? "remove" : "install");
            }
            onClicked: {
                if (root.installed) root.removeRequested(root.packageName, root.title);
                else root.installRequested(root.packageName, root.entry.source || "repo", root.title);
            }
        }
    }
}
