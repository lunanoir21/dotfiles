import QtQuick
import "../core"

// One line of status. The tone shows only in the dot.
Rectangle {
    id: root

    property string text: ""
    property string tone: "info"    // info | success | warning | danger
    property bool dismissible: false

    signal dismissed()

    readonly property color dotColor: {
        if (root.tone === "success") return DepotTheme.accent;
        if (root.tone === "warning") return DepotTheme.warning;
        if (root.tone === "danger") return DepotTheme.danger;
        return DepotTheme.overlay0;
    }

    implicitHeight: Math.max(40, message.implicitHeight + 20)
    radius: DepotTheme.radiusMedium
    color: DepotTheme.surface0
    border.width: 1
    border.color: DepotTheme.line

    Rectangle {
        id: dot
        width: 7
        height: 7
        radius: 3.5
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        color: root.dotColor
    }

    Text {
        id: message
        anchors.left: dot.right
        anchors.leftMargin: 11
        anchors.right: close.visible ? close.left : parent.right
        anchors.rightMargin: close.visible ? 6 : 14
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        color: DepotTheme.subtext0
        font.family: DepotTheme.sans
        font.pixelSize: 13
        wrapMode: Text.Wrap
        lineHeight: 1.15
    }

    Text {
        id: close
        visible: root.dismissible
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        text: DepotStrings.t("dismiss")
        color: closeMouse.containsMouse ? DepotTheme.text : DepotTheme.overlay0
        font.family: DepotTheme.sans
        font.pixelSize: 12
        font.weight: Font.Medium

        MouseArea {
            id: closeMouse
            anchors.fill: parent
            anchors.margins: -8
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.dismissed()
        }
    }
}
