import QtQuick
import QtQuick.Layouts

// Bir alt sayfaya ya da dış araca götüren satır: sağda chevron, opsiyonel
// durum metni. Tıklandığında `activated` sinyali gider.
Item {
    id: row

    property var theme
    property real sf: 1.0
    property string icon: ""
    property string label: ""
    property string hint: ""
    property string status: ""      // sağda, chevron'dan önce
    property color statusTone: theme ? theme.overlay0 : "#6c7086"

    signal activated()

    function s(v) { return Math.round(v * row.sf); }

    Layout.fillWidth: true
    implicitHeight: row.hint !== "" ? s(58) : s(44)

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: row.s(4)
        anchors.rightMargin: row.s(4)
        radius: row.s(10)
        color: ma.containsMouse
               ? Qt.rgba(row.theme.surface1.r, row.theme.surface1.g, row.theme.surface1.b, 0.45)
               : "transparent"
        Behavior on color { ColorAnimation { duration: 200 } }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.activated()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: row.s(14)
        anchors.rightMargin: row.s(14)
        spacing: row.s(11)

        Text {
            visible: row.icon !== ""
            text: row.icon
            font.family: "Iosevka Nerd Font"
            font.pixelSize: row.s(15)
            color: ma.containsMouse ? row.theme.mauve : row.theme.subtext0
            Behavior on color { ColorAnimation { duration: 200 } }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
                Layout.fillWidth: true
                text: row.label
                color: row.theme.text
                font.family: "JetBrains Mono"
                font.pixelSize: row.s(12)
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                visible: row.hint !== ""
                text: row.hint
                color: row.theme.overlay0
                font.family: "JetBrains Mono"
                font.pixelSize: row.s(10)
                elide: Text.ElideRight
            }
        }

        Text {
            visible: row.status !== ""
            text: row.status
            color: row.statusTone
            font.family: "JetBrains Mono"
            font.pixelSize: row.s(11)
            elide: Text.ElideRight
            Layout.maximumWidth: row.width * 0.35
        }

        Text {
            text: "󰅂"
            font.family: "Iosevka Nerd Font"
            font.pixelSize: row.s(12)
            color: row.theme.overlay0
            x: ma.containsMouse ? row.s(2) : 0
            Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        }
    }
}
