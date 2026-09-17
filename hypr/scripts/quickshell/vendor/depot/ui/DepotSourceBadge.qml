import QtQuick
import "../core"

// A small pill naming where a package comes from: Flathub, pacman, AUR...
Rectangle {
    id: root

    property string label: ""

    implicitWidth: text.implicitWidth + 14
    implicitHeight: 18
    radius: 9
    color: "transparent"
    border.width: 1
    border.color: DepotTheme.line

    Text {
        id: text
        anchors.centerIn: parent
        text: root.label
        color: DepotTheme.overlay0
        font.family: DepotTheme.mono
        font.pixelSize: 10
        font.weight: Font.Medium
    }
}
