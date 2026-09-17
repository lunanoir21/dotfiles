import QtQuick
import QtQuick.Layouts

// Satırın sağında bir düğme: "Eşleştir", "Unut", "Sıfırla" gibi tek seferlik
// eylemler. `danger` geri alınamayan işler için kırmızıya çevirir.
Item {
    id: row

    property var theme
    property real sf: 1.0
    property string label: ""
    property string hint: ""
    property string buttonText: ""
    property string buttonIcon: ""
    property bool danger: false
    property bool busy: false
    property bool enabledAction: true

    signal triggered()

    function s(v) { return Math.round(v * row.sf); }

    readonly property color tone: row.danger ? row.theme.red : row.theme.mauve

    Layout.fillWidth: true
    implicitHeight: row.hint !== "" ? s(58) : s(44)

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
            Layout.preferredWidth: btnRow.implicitWidth + row.s(24)
            Layout.preferredHeight: row.s(30)
            radius: row.s(9)
            opacity: row.enabledAction ? 1 : 0.4
            color: btnMa.containsMouse && row.enabledAction
                   ? Qt.rgba(row.tone.r, row.tone.g, row.tone.b, 0.26)
                   : Qt.rgba(row.tone.r, row.tone.g, row.tone.b, 0.13)
            border.width: 1
            border.color: Qt.rgba(row.tone.r, row.tone.g, row.tone.b, 0.45)
            Behavior on color { ColorAnimation { duration: 200 } }
            Behavior on opacity { NumberAnimation { duration: 200 } }

            scale: btnMa.pressed ? 0.95 : 1.0
            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }

            RowLayout {
                id: btnRow
                anchors.centerIn: parent
                spacing: row.s(6)

                Text {
                    visible: row.buttonIcon !== "" || row.busy
                    text: row.busy ? "󰑐" : row.buttonIcon
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: row.s(12)
                    color: row.tone

                    RotationAnimator on rotation {
                        running: row.busy
                        loops: Animation.Infinite
                        from: 0; to: 360
                        duration: 1100
                        alwaysRunToEnd: true
                    }
                }
                Text {
                    text: row.buttonText
                    color: row.theme.text
                    font.family: "JetBrains Mono"
                    font.pixelSize: row.s(11)
                }
            }

            MouseArea {
                id: btnMa
                anchors.fill: parent
                hoverEnabled: true
                enabled: row.enabledAction && !row.busy
                cursorShape: Qt.PointingHandCursor
                onClicked: row.triggered()
            }
        }
    }
}
