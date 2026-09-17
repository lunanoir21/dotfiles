import QtQuick
import QtQuick.Layouts

Item {
    id: row

    property var theme
    property real sf: 1.0
    property string label: ""
    property string hint: ""
    property bool checked: false

    signal toggled(bool value)

    function s(v) { return Math.round(v * row.sf); }

    Layout.fillWidth: true
    // Sabit yükseklik: ipucu metni sarılmıyor, eliyor. Yükseklik içeriğe
    // bağlansaydı satır bir layout içinde olduğu için binding döngüsü olurdu.
    implicitHeight: row.hint !== "" ? s(58) : s(44)

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: row.s(4)
        anchors.rightMargin: row.s(4)
        radius: row.s(10)
        color: hoverMa.containsMouse
               ? Qt.rgba(row.theme.surface1.r, row.theme.surface1.g, row.theme.surface1.b, 0.45)
               : "transparent"
        Behavior on color { ColorAnimation { duration: 200 } }
    }

    MouseArea {
        id: hoverMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.toggled(!row.checked)
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: row.s(14)
        anchors.rightMargin: row.s(14)
        spacing: row.s(12)

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

        Rectangle {
            Layout.preferredWidth: row.s(46)
            Layout.preferredHeight: row.s(25)
            radius: height / 2
            color: row.checked
                   ? row.theme.mauve
                   : Qt.rgba(row.theme.surface2.r, row.theme.surface2.g, row.theme.surface2.b, 0.85)
            Behavior on color { ColorAnimation { duration: 220 } }

            Rectangle {
                width: row.s(19)
                height: width
                radius: width / 2
                color: row.theme.crust
                y: (parent.height - height) / 2
                x: row.checked ? parent.width - width - row.s(3) : row.s(3)
                Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
            }
        }
    }
}
