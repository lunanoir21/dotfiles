import QtQuick
import Quickshell
import "../core"

// The desktop's own icon for the app when its theme has one, otherwise a
// monogram on a neutral tile.
Item {
    id: root

    property string iconName: ""
    property string label: ""
    property real size: 40

    readonly property string source: root.iconName ? Quickshell.iconPath(root.iconName, true) : ""

    implicitWidth: root.size
    implicitHeight: root.size

    Rectangle {
        anchors.fill: parent
        radius: DepotTheme.radiusMedium
        color: DepotTheme.surface1
        visible: image.status !== Image.Ready

        Text {
            anchors.centerIn: parent
            text: (root.label || "?").charAt(0).toUpperCase()
            color: DepotTheme.subtext0
            font.family: DepotTheme.display
            font.pixelSize: Math.round(root.size * 0.5)
            font.weight: Font.ExtraBold
        }
    }

    Image {
        id: image
        anchors.fill: parent
        source: root.source
        sourceSize: Qt.size(Math.round(root.size * 2), Math.round(root.size * 2))
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        mipmap: true
    }
}
