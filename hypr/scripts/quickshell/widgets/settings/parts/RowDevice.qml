import QtQuick
import QtQuick.Layouts

// Ağ / Bluetooth / ses sayfalarının ortak satırı: ikon, ad, alt bilgi, durum
// rozeti ve tıklandığında yerinde açılan eylem alanı.
//
// Eylemler default slot'tan geliyor — her sayfa kendi düğmelerini koyuyor,
// satırın kendisi sadece düzeni ve durumu biliyor.
Item {
    id: dev

    property var theme
    property real sf: 1.0

    property string icon: ""
    property color iconTone: theme ? theme.subtext0 : "#a6adc8"
    property string name: ""
    property string detail: ""
    property string status: ""
    property color statusTone: theme ? theme.overlay0 : "#6c7086"
    property bool connected: false
    property bool busy: false
    property string busyText: "bağlanıyor…"
    property bool expanded: false
    property bool dimmed: false     // menzil dışı / kullanılamaz

    default property alias actions: actionsCol.data

    signal clicked()

    function s(v) { return Math.round(v * dev.sf); }
    readonly property color accent: dev.connected ? dev.theme.green : dev.theme.mauve

    Layout.fillWidth: true
    implicitHeight: head.height + actWrap.height
    opacity: dev.dimmed ? 0.55 : 1
    Behavior on opacity { NumberAnimation { duration: 220 } }

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: dev.s(4)
        anchors.rightMargin: dev.s(4)
        radius: dev.s(12)
        color: dev.connected
               ? Qt.rgba(dev.theme.green.r, dev.theme.green.g, dev.theme.green.b, 0.10)
               : ((headMa.containsMouse || dev.expanded)
                  ? Qt.rgba(dev.theme.surface1.r, dev.theme.surface1.g, dev.theme.surface1.b, 0.5)
                  : "transparent")
        border.width: dev.connected || dev.expanded ? 1 : 0
        border.color: dev.connected
                      ? Qt.rgba(dev.theme.green.r, dev.theme.green.g, dev.theme.green.b, 0.55)
                      : Qt.rgba(dev.theme.mauve.r, dev.theme.mauve.g, dev.theme.mauve.b, 0.4)
        Behavior on color { ColorAnimation { duration: 220 } }
        Behavior on border.color { ColorAnimation { duration: 220 } }
    }

    Item {
        id: head
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: dev.s(52)

        MouseArea {
            id: headMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: dev.clicked()
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: dev.s(14)
            anchors.rightMargin: dev.s(14)
            spacing: dev.s(12)

            Text {
                text: dev.icon
                font.family: "Iosevka Nerd Font"
                font.pixelSize: dev.s(17)
                color: dev.connected ? dev.theme.green : dev.iconTone
                Behavior on color { ColorAnimation { duration: 220 } }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: dev.name
                    color: dev.connected ? dev.theme.text : dev.theme.subtext1
                    font.family: "JetBrains Mono"
                    font.pixelSize: dev.s(12)
                    font.weight: dev.connected ? Font.DemiBold : Font.Normal
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: dev.busy ? dev.busyText : dev.detail
                    color: dev.busy ? dev.theme.blue : dev.theme.overlay0
                    font.family: "JetBrains Mono"
                    font.pixelSize: dev.s(10)
                    elide: Text.ElideRight
                    Behavior on color { ColorAnimation { duration: 220 } }
                }
            }

            Pill {
                visible: dev.status !== ""
                theme: dev.theme
                sf: dev.sf
                text: dev.status
                tone: dev.statusTone
            }

            Text {
                text: "󰅀"
                font.family: "Iosevka Nerd Font"
                font.pixelSize: dev.s(10)
                color: dev.theme.overlay0
                rotation: dev.expanded ? 180 : 0
                Behavior on rotation { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
            }
        }
    }

    Item {
        id: actWrap
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: head.bottom
        clip: true

        property real openH: dev.expanded ? actionsCol.implicitHeight + dev.s(12) : 0
        Behavior on openH { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        height: openH
        opacity: dev.expanded ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        ColumnLayout {
            id: actionsCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: dev.s(14)
            anchors.rightMargin: dev.s(14)
            anchors.bottomMargin: dev.s(12)
            spacing: dev.s(7)
        }
    }
}
