import QtQuick
import QtQuick.Layouts

// Boş liste ekranı. Sessiz bir hata mesajı değil, ne yapılacağını söyleyen
// bir davet: başlık ne olduğunu, gövde sıradaki adımı anlatır.
Item {
    id: es

    property var theme
    property real sf: 1.0
    property string icon: "󰋼"
    property string headline: ""
    property string body: ""
    property string actionText: ""
    property bool busy: false

    signal actionTriggered()

    function s(v) { return Math.round(v * es.sf); }

    Layout.fillWidth: true
    implicitHeight: col.implicitHeight + s(48)

    ColumnLayout {
        id: col
        anchors.centerIn: parent
        width: Math.min(es.width - es.s(48), es.s(340))
        spacing: es.s(10)

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: es.busy ? "󰑐" : es.icon
            font.family: "Iosevka Nerd Font"
            font.pixelSize: es.s(34)
            color: Qt.rgba(es.theme.overlay0.r, es.theme.overlay0.g, es.theme.overlay0.b, 0.7)

            RotationAnimator on rotation {
                running: es.busy
                loops: Animation.Infinite
                from: 0; to: 360
                duration: 1400
                alwaysRunToEnd: true
            }
        }

        Text {
            Layout.fillWidth: true
            visible: es.headline !== ""
            horizontalAlignment: Text.AlignHCenter
            text: es.headline
            color: es.theme.subtext1
            font.family: "JetBrains Mono"
            font.weight: Font.DemiBold
            font.pixelSize: es.s(13)
            wrapMode: Text.WordWrap
        }

        Text {
            Layout.fillWidth: true
            visible: es.body !== ""
            horizontalAlignment: Text.AlignHCenter
            text: es.body
            color: es.theme.overlay0
            font.family: "JetBrains Mono"
            font.pixelSize: es.s(11)
            wrapMode: Text.WordWrap
            lineHeight: 1.35
        }

        Rectangle {
            visible: es.actionText !== ""
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: es.s(4)
            implicitWidth: actLabel.implicitWidth + es.s(28)
            implicitHeight: es.s(32)
            radius: es.s(10)
            color: actMa.containsMouse
                   ? Qt.rgba(es.theme.mauve.r, es.theme.mauve.g, es.theme.mauve.b, 0.26)
                   : Qt.rgba(es.theme.mauve.r, es.theme.mauve.g, es.theme.mauve.b, 0.14)
            border.width: 1
            border.color: Qt.rgba(es.theme.mauve.r, es.theme.mauve.g, es.theme.mauve.b, 0.45)
            Behavior on color { ColorAnimation { duration: 200 } }
            scale: actMa.pressed ? 0.95 : 1.0
            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }

            Text {
                id: actLabel
                anchors.centerIn: parent
                text: es.actionText
                color: es.theme.text
                font.family: "JetBrains Mono"
                font.pixelSize: es.s(11)
            }

            MouseArea {
                id: actMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: es.actionTriggered()
            }
        }
    }
}
