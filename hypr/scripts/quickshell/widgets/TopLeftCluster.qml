import QtQuick
import QtQuick.Layouts
import "../core"

Rectangle {
    id: root

    required property var workspaceModel
    // Renkler ortak kaynaktan (qs_colors.json -> MatugenColors) geliyor ve
    // yukarıdan geçiriliyor. Kendi MatugenColors'ını kurmuyor: o bileşen
    // saniyede bir `cat` süreci açan bir Timer taşıyor, her widget kendi
    // kopyasını açarsa bar tek başına yavaşlıyor.
    property var theme
    property real uiScale: 1.0
    property bool enabledState: true
    property bool revealed: false
    readonly property int activeIndex: workspaceModel ? workspaceModel.activeIndex : 0

    signal searchRequested()
    signal settingsRequested()
    signal workspaceRequested(string workspaceId)

    function s(value) { return Math.round(value * uiScale); }

    // Qt.rgba(1,1,1,a) "beyaz katman" demek ve yalnızca koyu zeminde doğru;
    // açık temada beyaz üstüne beyaz koyuyordu. Katmanlar artık temanın metin
    // rengini kullanıyor: koyu temada beyaza, açık temada koyuya düşüyor.
    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }

    implicitWidth: contentRow.implicitWidth + s(14)
    implicitHeight: s(48)
    width: implicitWidth
    height: implicitHeight
    radius: s(16)
    color: root.tint(root.theme.crust, 0.94)
    border.width: 1
    border.color: root.tint(root.theme.text, 0.075)
    clip: true
    enabled: enabledState

    opacity: revealed ? 1 : 0
    transform: Translate {
        y: root.revealed ? 0 : -root.s(7)
        Behavior on y {
            NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
        }
    }
    Behavior on opacity {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    Component.onCompleted: revealTimer.start()

    Timer {
        id: revealTimer
        interval: 30
        repeat: false
        onTriggered: root.revealed = true
    }

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: root.tint(root.theme.text, 0.045)
    }

    Row {
        id: contentRow
        anchors.left: parent.left
        anchors.leftMargin: root.s(7)
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.s(4)

        Rectangle {
            id: searchButton
            width: root.s(36)
            height: root.s(36)
            radius: root.s(11)
            color: searchMouse.containsMouse
                ? root.tint(root.theme.text, 0.105)
                : "transparent"

            Behavior on color { ColorAnimation { duration: 140 } }

            Text {
                anchors.centerIn: parent
                text: "󰍉"
                color: searchMouse.containsMouse ? root.theme.text : root.theme.subtext1
                font.family: "Iosevka Nerd Font"
                font.pixelSize: root.s(19)
                scale: searchMouse.pressed ? 0.88 : (searchMouse.containsMouse ? 1.06 : 1)
                Behavior on scale {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }
                Behavior on color { ColorAnimation { duration: 140 } }
            }

            MouseArea {
                id: searchMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.searchRequested()
            }
        }

        Rectangle {
            id: settingsButton
            width: root.s(36)
            height: root.s(36)
            radius: root.s(11)
            color: settingsMouse.containsMouse
                ? root.tint(root.theme.peach, 0.14)
                : "transparent"

            Behavior on color { ColorAnimation { duration: 140 } }

            Text {
                anchors.centerIn: parent
                text: ""
                color: settingsMouse.containsMouse ? root.theme.peach : root.theme.subtext1
                font.family: "Iosevka Nerd Font"
                font.pixelSize: root.s(19)
                rotation: settingsMouse.containsMouse ? 22 : 0
                scale: settingsMouse.pressed ? 0.88 : 1
                Behavior on rotation {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }
                Behavior on scale {
                    NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
                }
                Behavior on color { ColorAnimation { duration: 140 } }
            }

            MouseArea {
                id: settingsMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.settingsRequested()
            }
        }

        Item { width: root.s(5); height: 1 }

        Rectangle {
            width: 1
            height: root.s(20)
            anchors.verticalCenter: parent.verticalCenter
            color: root.tint(root.theme.text, 0.12)
        }

        Item { width: root.s(5); height: 1 }

        Item {
            id: workspaceRail
            width: workspaceRow.implicitWidth
            height: root.s(36)

            Rectangle {
                id: activeHighlight
                x: root.activeIndex * (root.s(32) + workspaceRow.spacing)
                y: root.s(2)
                width: root.s(32)
                height: root.s(32)
                radius: root.s(11)
                color: root.theme.text
                opacity: root.workspaceModel && root.workspaceModel.count > 0 ? 1 : 0
                z: 0

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: root.s(3)
                    width: root.s(8)
                    height: root.s(2)
                    radius: 1
                    color: root.theme.peach
                    opacity: 0.8
                }

                Behavior on x {
                    NumberAnimation { duration: 230; easing.type: Easing.OutCubic }
                }
            }

            Row {
                id: workspaceRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: root.s(4)

                Repeater {
                    model: root.workspaceModel

                    delegate: Rectangle {
                        id: workspaceButton
                        required property int index
                        required property string wsId
                        required property string wsState

                        readonly property bool active: index === root.activeIndex
                        readonly property bool occupied: wsState === "occupied"
                        readonly property bool hovered: workspaceMouse.containsMouse

                        width: root.s(32)
                        height: root.s(32)
                        radius: root.s(11)
                        color: active
                            ? "transparent"
                            : (hovered
                                ? root.tint(root.theme.text, 0.115)
                                : (occupied ? root.tint(root.theme.text, 0.07) : "transparent"))
                        z: 1

                        Behavior on color { ColorAnimation { duration: 140 } }

                        Text {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: workspaceButton.active ? -root.s(1) : 0
                            text: workspaceButton.wsId
                            color: workspaceButton.active
                                ? root.theme.crust
                                : (workspaceButton.hovered
                                    ? root.theme.text
                                    : (workspaceButton.occupied ? root.theme.subtext1 : root.theme.overlay0))
                            font.family: "Bricolage Grotesque"
                            font.pixelSize: root.s(13)
                            font.weight: workspaceButton.active ? Font.DemiBold : Font.Medium

                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        Rectangle {
                            visible: workspaceButton.occupied && !workspaceButton.active
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: root.s(3)
                            width: root.s(3)
                            height: root.s(3)
                            radius: width / 2
                            color: root.theme.overlay1
                            opacity: workspaceButton.hovered ? 1 : 0.55
                            Behavior on opacity { NumberAnimation { duration: 130 } }
                        }

                        MouseArea {
                            id: workspaceMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.workspaceRequested(workspaceButton.wsId)
                        }
                    }
                }
            }
        }
    }
}
