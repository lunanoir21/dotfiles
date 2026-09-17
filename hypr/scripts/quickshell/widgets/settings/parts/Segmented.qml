pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

// Yan yana seçenek çipleri. Açılır liste yerine bu tercih edildi: Flickable
// içinde popup'lar z-sırası ve kırpma sorunu çıkarıyor.
Item {
    id: seg

    property var theme
    property real sf: 1.0
    property var options: []        // ["bind", "binde", ...]
    property var labels: null       // opsiyonel görünen adlar; yoksa options
    property int currentIndex: 0

    signal picked(int index)

    function s(v) { return Math.round(v * seg.sf); }

    implicitHeight: s(28)
    implicitWidth: rowl.implicitWidth

    RowLayout {
        id: rowl
        anchors.fill: parent
        spacing: seg.s(4)

        Repeater {
            model: seg.options

            delegate: Rectangle {
                id: chip

                required property int index
                required property var modelData

                readonly property bool active: seg.currentIndex === chip.index

                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: seg.s(7)
                color: chip.active
                       ? Qt.rgba(seg.theme.mauve.r, seg.theme.mauve.g, seg.theme.mauve.b, 0.28)
                       : (chipMa.containsMouse
                          ? Qt.rgba(seg.theme.surface2.r, seg.theme.surface2.g, seg.theme.surface2.b, 0.7)
                          : Qt.rgba(seg.theme.surface1.r, seg.theme.surface1.g, seg.theme.surface1.b, 0.55))
                border.width: 1
                border.color: chip.active ? seg.theme.mauve : "transparent"
                Behavior on color { ColorAnimation { duration: 180 } }
                Behavior on border.color { ColorAnimation { duration: 180 } }
                scale: chipMa.pressed ? 0.94 : 1.0
                Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }

                Text {
                    anchors.centerIn: parent
                    text: seg.labels ? seg.labels[chip.index] : chip.modelData
                    color: chip.active ? seg.theme.text : seg.theme.subtext0
                    font.family: "JetBrains Mono"
                    font.weight: chip.active ? Font.DemiBold : Font.Normal
                    font.pixelSize: seg.s(10)
                    Behavior on color { ColorAnimation { duration: 180 } }
                }

                MouseArea {
                    id: chipMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: seg.picked(chip.index)
                }
            }
        }
    }
}
