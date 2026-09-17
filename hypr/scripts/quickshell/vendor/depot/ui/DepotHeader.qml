import QtQuick
import "../core"

// Just the mark and the name; the backend badge and theme switch live in
// the Settings page now that Depot has real navigation.
Item {
    id: root

    implicitHeight: 44

    Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        DepotSealMark {
            size: 34
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Depot"
            color: DepotTheme.text
            font.family: DepotTheme.display
            font.pixelSize: 32
            font.weight: Font.ExtraBold
        }
    }
}
