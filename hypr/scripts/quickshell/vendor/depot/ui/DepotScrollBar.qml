import QtQuick
import "../core"

// A thin bar that follows a Flickable; drawn here so it looks the same under
// every Qt Quick Controls style.
Item {
    id: root

    required property Flickable flickable

    width: 10
    visible: root.flickable.visibleArea.heightRatio < 1

    Rectangle {
        x: 3
        width: dragArea.pressed || hover.hovered ? 6 : 4
        radius: width / 2
        y: root.flickable.visibleArea.yPosition * root.height
        height: Math.max(28, root.flickable.visibleArea.heightRatio * root.height)
        color: dragArea.pressed ? DepotTheme.subtext0 : DepotTheme.surface1
        opacity: root.flickable.moving || hover.hovered || dragArea.pressed ? 1 : 0.6

        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    HoverHandler { id: hover }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        onPressed: mouse => root.scrollTo(mouse.y)
        onPositionChanged: mouse => { if (pressed) root.scrollTo(mouse.y) }
    }

    function scrollTo(y) {
        let f = root.flickable;
        let ratio = Math.max(0, Math.min(1, y / root.height));
        f.contentY = Math.max(0, Math.min(f.contentHeight - f.height, ratio * f.contentHeight - f.height / 2));
    }
}
