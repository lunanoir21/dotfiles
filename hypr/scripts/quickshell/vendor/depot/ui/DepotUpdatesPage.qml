import QtQuick
import "../core"

// Mock "Updates" tab: the real backend has no update feed yet, so this shows
// the up-to-date state with a preview of what the badge/list will look like.
Column {
    id: root

    spacing: 20

    Row {
        width: parent.width

        Text {
            width: parent.width - button.width
            text: DepotStrings.t("noUpdates")
            color: DepotTheme.text
            font.family: DepotTheme.sans
            font.pixelSize: 15
            font.weight: Font.Medium
            verticalAlignment: Text.AlignVCenter
            height: button.height
        }

        DepotButton {
            id: button
            text: DepotStrings.t("updateAll")
            variant: "outline"
            enabled: false
        }
    }

    DepotNotice {
        width: parent.width
        tone: "info"
        text: DepotStrings.t("mockNotice")
    }
}
