import QtQuick
import "../core"

// Left a category list, right a grid of that category's apps — the AppStream
// categories used across GNOME Software / Discover.
Item {
    id: root

    readonly property var categoryOrder: ["internet", "communication", "office", "development", "media", "system"]
    property string current: root.categoryOrder[0]

    signal opened(var entry)

    implicitHeight: Math.max(list.implicitHeight, grid.implicitHeight)

    Column {
        id: list
        width: 168
        anchors.top: parent.top
        anchors.left: parent.left
        spacing: 2

        Repeater {
            model: root.categoryOrder

            Rectangle {
                id: item
                required property string modelData
                readonly property bool active: modelData === root.current
                width: list.width
                height: 36
                radius: DepotTheme.radiusSmall
                color: active ? DepotTheme.surface0 : (mouse.containsMouse ? DepotTheme.surface0 : "transparent")

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: DepotStrings.t(item.modelData)
                    color: item.active ? DepotTheme.text : DepotTheme.subtext0
                    font.family: DepotTheme.sans
                    font.pixelSize: 14
                    font.weight: item.active ? Font.DemiBold : Font.Normal
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.current = item.modelData
                }
            }
        }
    }

    Grid {
        id: grid
        anchors.top: parent.top
        anchors.left: list.right
        anchors.leftMargin: 24
        anchors.right: parent.right
        columns: Math.max(1, Math.floor((width + 12) / 180))
        columnSpacing: 12
        rowSpacing: 12

        Repeater {
            model: DepotBackend.featured.filter(e => e.category === root.current)

            DepotAppCard {
                required property var modelData
                required property int index
                width: 168
                height: 168
                entry: modelData
                entranceDelay: index * 30
                onOpened: entry => root.opened(entry)
            }
        }
    }

    Text {
        anchors.top: parent.top
        anchors.left: list.right
        anchors.leftMargin: 24
        visible: grid.children.length <= 1
        text: DepotStrings.t("noAppsInCategory")
        color: DepotTheme.overlay0
        font.family: DepotTheme.sans
        font.pixelSize: 13
    }
}
