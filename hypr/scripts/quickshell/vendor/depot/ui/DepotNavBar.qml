import QtQuick
import "../core"

// A top tab strip like GNOME Software's Explore / Installed / Updates row.
// The underline draws itself in on the active tab rather than jumping.
Item {
    id: root

    property string current: "explore"
    property var tabs: [
        { id: "explore", key: "navExplore" },
        { id: "categories", key: "navCategories" },
        { id: "installed", key: "navInstalled" },
        { id: "updates", key: "navUpdates" },
        { id: "settings", key: "navSettings" }
    ]

    signal selected(string tabId)

    implicitHeight: 34

    Row {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        spacing: 4

        Repeater {
            model: root.tabs

            Item {
                id: tabItem
                required property var modelData
                readonly property bool active: modelData.id === root.current
                width: label.implicitWidth + 4
                height: 34

                Text {
                    id: label
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    text: DepotStrings.t(tabItem.modelData.key)
                    color: tabItem.active ? DepotTheme.text : (mouse.containsMouse ? DepotTheme.subtext0 : DepotTheme.overlay0)
                    font.family: DepotTheme.sans
                    font.pixelSize: 14
                    font.weight: tabItem.active ? Font.DemiBold : Font.Medium
                    scale: mouse.pressed ? 0.96 : 1

                    Behavior on color { ColorAnimation { duration: 100 } }
                    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 2
                    radius: 1
                    color: DepotTheme.text
                    opacity: tabItem.active ? 1 : 0
                    scale: tabItem.active ? 1 : 0.25
                    transformOrigin: Item.Center

                    Behavior on opacity { NumberAnimation { duration: 140 } }
                    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2 } }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selected(tabItem.modelData.id)
                }
            }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: DepotTheme.line
    }
}
