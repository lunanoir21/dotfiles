import QtQuick
import "../core"

// filled: the text color as the fill; outline: a hairline; danger: armed
// confirmation. Green is never a button color.
Item {
    id: root

    property string text: ""
    property string variant: "filled"   // filled | outline | danger
    property bool busy: false

    signal clicked()

    readonly property bool active: root.enabled && !root.busy
    readonly property color ink: {
        if (!root.enabled && !root.busy) return DepotTheme.overlay0;
        if (root.variant === "filled") return DepotTheme.primaryInk;
        if (root.variant === "danger") return DepotTheme.danger;
        return DepotTheme.text;
    }

    implicitWidth: Math.max(88, label.implicitWidth + 28)
    implicitHeight: 32
    activeFocusOnTab: root.active
    scale: mouse.pressed && root.active ? 0.955 : 1

    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        radius: DepotTheme.radiusSmall
        color: {
            if (root.variant !== "filled" || (!root.enabled && !root.busy)) {
                return mouse.containsMouse && root.active ? DepotTheme.surface1 : "transparent";
            }
            return mouse.containsMouse && root.active ? DepotTheme.alpha(DepotTheme.primary, 0.86) : DepotTheme.primary;
        }
        border.width: root.variant === "filled" && (root.enabled || root.busy) ? 0 : 1
        border.color: root.variant === "danger" ? DepotTheme.alpha(DepotTheme.danger, 0.6) : DepotTheme.line
        opacity: root.busy ? 0.7 : 1

        Behavior on color { ColorAnimation { duration: 120 } }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: DepotTheme.radiusSmall + 3
        color: "transparent"
        border.width: 2
        border.color: DepotTheme.accent
        visible: root.activeFocus
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: root.ink
        font.family: DepotTheme.sans
        font.pixelSize: 13
        font.weight: Font.Medium

        SequentialAnimation on opacity {
            running: root.busy
            loops: Animation.Infinite
            alwaysRunToEnd: true
            NumberAnimation { to: 0.45; duration: 600; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutSine }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.active ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (root.active) root.clicked()
    }

    Keys.onPressed: event => {
        if (root.active && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)) {
            root.clicked();
            event.accepted = true;
        }
    }
}
