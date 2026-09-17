import QtQuick
import QtQuick.Layouts
import Quickshell

// Salt okunur bilgi satırı: solda ne olduğu, sağda değeri. Değere tıklayınca
// panoya kopyalanır — MAC adresi, IP, kernel sürümü gibi şeyler için.
Item {
    id: row

    property var theme
    property real sf: 1.0
    property string label: ""
    property string value: ""
    property bool copyable: false
    property color tone: theme ? theme.subtext1 : "#bac2de"

    function s(v) { return Math.round(v * row.sf); }

    Layout.fillWidth: true
    implicitHeight: s(38)

    property bool justCopied: false
    Timer { id: copiedReset; interval: 1200; onTriggered: row.justCopied = false }

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: row.s(4)
        anchors.rightMargin: row.s(4)
        radius: row.s(10)
        color: (row.copyable && ma.containsMouse)
               ? Qt.rgba(row.theme.surface1.r, row.theme.surface1.g, row.theme.surface1.b, 0.4)
               : "transparent"
        Behavior on color { ColorAnimation { duration: 200 } }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: row.copyable
        enabled: row.copyable
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            // wl-copy stdin'den okur; değeri argüman yapmak tırnak sorunlarına
            // açık, o yüzden printf ile besliyoruz.
            Quickshell.execDetached(["bash", "-c",
                "printf '%s' \"$1\" | wl-copy", "_", row.value]);
            row.justCopied = true;
            copiedReset.restart();
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: row.s(14)
        anchors.rightMargin: row.s(14)
        spacing: row.s(12)

        Text {
            text: row.label
            color: row.theme.overlay0
            font.family: "JetBrains Mono"
            font.pixelSize: row.s(11)
        }

        Item { Layout.fillWidth: true }

        Text {
            text: row.justCopied ? "kopyalandı" : row.value
            color: row.justCopied ? row.theme.green : row.tone
            font.family: "JetBrains Mono"
            font.pixelSize: row.s(11)
            elide: Text.ElideLeft
            Layout.maximumWidth: row.width * 0.6
            Behavior on color { ColorAnimation { duration: 200 } }
        }

        Text {
            visible: row.copyable
            text: "󰆏"
            font.family: "Iosevka Nerd Font"
            font.pixelSize: row.s(11)
            color: ma.containsMouse ? row.theme.mauve : row.theme.overlay0
            Behavior on color { ColorAnimation { duration: 200 } }
        }
    }
}
