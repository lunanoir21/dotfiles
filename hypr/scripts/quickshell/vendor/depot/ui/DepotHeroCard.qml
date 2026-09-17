import QtQuick
import "../core"

// The large "editor's choice" card. A mock gradient stands in for a
// screenshot until real AppStream art is wired up. The corner tag borrows
// the seal's diamond shape to mark a pick as curated, not just popular.
Item {
    id: root

    property var entry: ({})
    property int entranceDelay: 0

    signal opened(var entry)

    implicitWidth: 360
    implicitHeight: 220
    opacity: 0
    scale: press.pressed ? 0.982 : (hover.hovered ? 1.008 : 1)

    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    transform: Translate { id: entranceShift; y: 16 }

    Component.onCompleted: entrance.start()

    SequentialAnimation {
        id: entrance
        PauseAnimation { duration: Math.min(root.entranceDelay, 300) }
        ParallelAnimation {
            NumberAnimation { target: root; property: "opacity"; to: 1; duration: 260; easing.type: Easing.OutCubic }
            NumberAnimation { target: entranceShift; property: "y"; to: 0; duration: 360; easing.type: Easing.OutCubic }
        }
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: DepotTheme.radiusLarge
        color: DepotTheme.mantle
        border.width: 1
        border.color: hover.hovered ? DepotTheme.overlay0 : DepotTheme.line

        Behavior on border.color { ColorAnimation { duration: 120 } }
    }

    HoverHandler { id: hover }
    TapHandler { id: press; onTapped: root.opened(root.entry) }

    Rectangle {
        id: art
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 1
        height: parent.height * 0.58
        radius: DepotTheme.radiusLarge
        color: DepotTheme.surface0

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: parent.height / 2
            radius: DepotTheme.radiusLarge
            color: DepotTheme.surface0
        }

        DepotAppIcon {
            anchors.centerIn: parent
            size: 56
            iconName: root.entry.icon || root.entry.package || ""
            label: root.entry.name || ""
        }

        Item {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 10
            width: tagLabel.implicitWidth + 16
            height: 20
            rotation: -6

            Rectangle {
                anchors.fill: parent
                radius: 3
                color: "transparent"
                border.width: 1
                border.color: DepotTheme.tagStroke
            }
            Text {
                id: tagLabel
                anchors.centerIn: parent
                text: DepotStrings.t("editorsChoice")
                color: DepotTheme.subtext0
                font.family: DepotTheme.mono
                font.pixelSize: 9
                font.weight: Font.Medium
                font.letterSpacing: 0.6
            }
        }
    }

    Column {
        anchors.top: art.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16
        anchors.topMargin: 12
        spacing: 4

        Text {
            width: parent.width
            text: root.entry.name || ""
            color: DepotTheme.text
            font.family: DepotTheme.sans
            font.pixelSize: 16
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: DepotStrings.pick(root.entry.description)
            color: DepotTheme.subtext0
            font.family: DepotTheme.sans
            font.pixelSize: 12
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }
}
