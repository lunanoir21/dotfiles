import QtQuick
import QtQuick.Layouts

// Başlıklı ayar grubu. İçine konan satırlar (RowToggle/RowSlider/...) doğrudan
// kartın gövdesine akar.
//
// theme ve sf yukarıdan geçiliyor, her parça kendi MatugenColors'ını kurmuyor:
// MatugenColors saniyede bir `cat` süreci başlatan bir Timer taşıyor, onlarca
// kopya açmak paneli tek başına diz çöktürürdü.
Item {
    id: card

    property var theme
    property real sf: 1.0
    property string title: ""

    default property alias content: inner.data

    function s(v) { return Math.round(v * card.sf); }

    Layout.fillWidth: true
    implicitHeight: col.implicitHeight

    ColumnLayout {
        id: col
        width: card.width
        spacing: card.s(8)

        Text {
            visible: card.title !== ""
            text: card.title
            color: card.theme.subtext0
            font.family: "JetBrains Mono"
            font.weight: Font.Bold
            font.pixelSize: card.s(11)
            Layout.leftMargin: card.s(4)
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: inner.implicitHeight + card.s(12)
            radius: card.s(14)
            color: Qt.rgba(card.theme.surface0.r, card.theme.surface0.g, card.theme.surface0.b, 0.5)
            border.width: 1
            border.color: Qt.rgba(card.theme.text.r, card.theme.text.g, card.theme.text.b, 0.06)

            ColumnLayout {
                id: inner
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: card.s(6)
                spacing: card.s(2)
            }
        }
    }
}
