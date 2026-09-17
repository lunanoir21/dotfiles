import QtQuick
import "../core"

// A manifest tag, not a generic tile: icon and name on top, a perforation
// tear, then a mono strip naming where the package ships from — the same
// silhouette as a shipping label, echoing the seal's diamond tag.
Item {
    id: root

    property var entry: ({})
    property int entranceDelay: 0
    readonly property string packageName: root.entry.package || ""
    readonly property bool installed: root.entry.installed === true
    readonly property string primarySource: {
        let sources = DepotMock.sourcesFor(root.entry);
        return sources.length > 0 ? sources[0].label : "";
    }

    signal opened(var entry)

    implicitWidth: 168
    implicitHeight: 168
    opacity: 0
    scale: press.pressed ? 0.972 : (hover.hovered ? 1.012 : 1)

    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    transform: Translate { id: entranceShift; y: 12 }

    Component.onCompleted: entrance.start()

    SequentialAnimation {
        id: entrance
        PauseAnimation { duration: Math.min(root.entranceDelay, 260) }
        ParallelAnimation {
            NumberAnimation { target: root; property: "opacity"; to: 1; duration: 240; easing.type: Easing.OutCubic }
            NumberAnimation { target: entranceShift; property: "y"; to: 0; duration: 320; easing.type: Easing.OutCubic }
        }
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: DepotTheme.radiusLarge
        color: hover.hovered ? DepotTheme.surface0 : DepotTheme.mantle
        border.width: 1
        border.color: hover.hovered ? DepotTheme.overlay0 : DepotTheme.line

        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }
    }

    HoverHandler { id: hover }
    TapHandler { id: press; onTapped: root.opened(root.entry) }

    Column {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        Item {
            width: parent.width
            height: 48

            DepotAppIcon {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                size: 48
                iconName: root.entry.icon || root.packageName
                label: root.entry.name || ""
            }

            Rectangle {
                id: installedDot
                visible: root.installed
                anchors.right: parent.right
                anchors.top: parent.top
                width: 8
                height: 8
                radius: 4
                color: DepotTheme.accent
                scale: 1
                transformOrigin: Item.Center

                onVisibleChanged: if (visible) popIn.start()

                SequentialAnimation {
                    id: popIn
                    NumberAnimation { target: installedDot; property: "scale"; from: 0.2; to: 1.35; duration: 160; easing.type: Easing.OutCubic }
                    NumberAnimation { target: installedDot; property: "scale"; to: 1; duration: 140; easing.type: Easing.OutBack; easing.overshoot: 3 }
                }
            }
        }

        Text {
            width: parent.width
            text: root.entry.name || ""
            color: DepotTheme.text
            font.family: DepotTheme.sans
            font.pixelSize: 14
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            height: 32
            text: DepotStrings.pick(root.entry.description)
            color: DepotTheme.subtext0
            font.family: DepotTheme.sans
            font.pixelSize: 12
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        DepotDashedDivider {
            width: parent.width
        }

        Text {
            visible: root.primarySource !== ""
            text: root.primarySource.toUpperCase()
            color: DepotTheme.overlay0
            font.family: DepotTheme.mono
            font.pixelSize: 10
            font.weight: Font.Medium
            font.letterSpacing: 1.2
        }
    }
}
