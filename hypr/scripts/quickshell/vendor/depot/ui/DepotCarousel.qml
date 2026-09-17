import QtQuick
import "../core"

// A titled, horizontally scrolling strip of cards — GNOME Software's
// "Popular this week" / "New and updated" rows.
Column {
    id: root

    property string title: ""
    property var entries: []
    property real cardWidth: 168
    property real cardHeight: 168

    signal opened(var entry)

    spacing: 10

    Text {
        leftPadding: 2
        text: root.title.toUpperCase()
        color: DepotTheme.overlay0
        font.family: DepotTheme.mono
        font.pixelSize: 11
        font.weight: Font.Medium
        font.letterSpacing: 1.4
    }

    ListView {
        width: root.width
        height: root.cardHeight
        orientation: ListView.Horizontal
        spacing: 12
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.entries

        delegate: DepotAppCard {
            required property var modelData
            required property int index
            width: root.cardWidth
            height: root.cardHeight
            entry: modelData
            entranceDelay: index * 35
            onOpened: entry => root.opened(entry)
        }
    }
}
