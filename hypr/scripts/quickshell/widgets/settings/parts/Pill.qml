import QtQuick

// Küçük durum rozeti: nav satırlarındaki canlı bilgi ("%68", "TurkTelekom"),
// kart başlıklarındaki sayaçlar, cihaz satırlarındaki "bağlı" etiketi.
Item {
    id: pill

    property var theme
    property real sf: 1.0
    property string text: ""
    property color tone: theme ? theme.overlay0 : "#6c7086"
    property bool solid: false      // true = dolu zemin, false = soluk zemin

    function s(v) { return Math.round(v * pill.sf); }

    implicitWidth: label.implicitWidth + s(14)
    implicitHeight: s(18)

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: pill.solid ? pill.tone
                          : Qt.rgba(pill.tone.r, pill.tone.g, pill.tone.b, 0.16)
        Behavior on color { ColorAnimation { duration: 200 } }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: pill.text
        color: pill.solid ? (pill.theme ? pill.theme.crust : "#11111b") : pill.tone
        font.family: "JetBrains Mono"
        font.pixelSize: pill.s(9)
        font.weight: Font.DemiBold
        Behavior on color { ColorAnimation { duration: 200 } }
    }
}
