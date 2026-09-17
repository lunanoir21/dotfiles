import QtQuick
import QtQuick.Layouts
import Quickshell

// Henüz yeni pencereye taşınmamış kategoriler için geçici köprü. Kısayol ve
// monitör editörleri eski panelde çalışmaya devam ediyor; buradan açılıyorlar
// ki taşıma tamamlanana kadar hiçbir ayar erişilemez hale gelmesin.
ColumnLayout {
    id: page

    property var theme
    property real sf: 1.0
    property string icon: "󰇘"
    property string headline: ""
    property string body: ""
    property string legacyTarget: ""   // boşsa düğme gizlenir

    readonly property bool hasSave: false
    readonly property bool dirty: false
    function save() {}

    function s(v) { return Math.round(v * page.sf); }

    Item { Layout.fillHeight: true }

    Text {
        Layout.alignment: Qt.AlignHCenter
        text: page.icon
        font.family: "Iosevka Nerd Font"
        font.pixelSize: page.s(46)
        color: Qt.rgba(page.theme.overlay0.r, page.theme.overlay0.g, page.theme.overlay0.b, 0.7)
    }

    Text {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: page.s(14)
        text: page.headline
        color: page.theme.text
        font.family: "JetBrains Mono"
        font.weight: Font.DemiBold
        font.pixelSize: page.s(14)
    }

    Text {
        Layout.fillWidth: true
        Layout.topMargin: page.s(6)
        Layout.maximumWidth: page.s(420)
        Layout.alignment: Qt.AlignHCenter
        text: page.body
        horizontalAlignment: Text.AlignHCenter
        color: page.theme.overlay0
        font.family: "JetBrains Mono"
        font.pixelSize: page.s(11)
        wrapMode: Text.WordWrap
    }

    Rectangle {
        visible: page.legacyTarget !== ""
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: page.s(20)
        Layout.preferredWidth: page.s(190)
        Layout.preferredHeight: page.s(36)
        radius: page.s(11)
        color: openMa.containsMouse
               ? Qt.rgba(page.theme.mauve.r, page.theme.mauve.g, page.theme.mauve.b, 0.28)
               : Qt.rgba(page.theme.surface1.r, page.theme.surface1.g, page.theme.surface1.b, 0.75)
        border.width: 1
        border.color: openMa.containsMouse
                      ? page.theme.mauve
                      : Qt.rgba(page.theme.text.r, page.theme.text.g, page.theme.text.b, 0.08)
        Behavior on color { ColorAnimation { duration: 200 } }
        Behavior on border.color { ColorAnimation { duration: 200 } }
        scale: openMa.pressed ? 0.95 : 1.0
        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }

        RowLayout {
            anchors.centerIn: parent
            spacing: page.s(7)
            Text {
                text: "󰏋"
                font.family: "Iosevka Nerd Font"
                font.pixelSize: page.s(12)
                color: page.theme.text
            }
            Text {
                text: "Eski panelde aç"
                color: page.theme.text
                font.family: "JetBrains Mono"
                font.pixelSize: page.s(11)
            }
        }

        MouseArea {
            id: openMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Quickshell.execDetached(["bash", "-c",
                "~/.config/hypr/scripts/qs_manager.sh toggle " + page.legacyTarget])
        }
    }

    Item { Layout.fillHeight: true }
}
