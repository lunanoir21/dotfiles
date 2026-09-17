// StepButton inline bileşeni dıştaki `row` id'sine erişiyor; Qt bunun için
// açık bağlama istiyor. Bu dosyada delegate yok, pragma'nın başka etkisi olmuyor.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

Item {
    id: row

    property var theme
    property real sf: 1.0
    property string label: ""
    property string hint: ""
    property int value: 0
    property int from: 0
    property int to: 100
    property int step: 1

    signal changed(int v)

    function s(v) { return Math.round(v * row.sf); }
    function clamp(v) { return Math.max(row.from, Math.min(row.to, v)); }
    function bump(dir) {
        let next = row.clamp(row.value + dir * row.step);
        if (next !== row.value) row.changed(next);
    }

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
            Layout.preferredWidth: row.s(110)
            Layout.preferredHeight: row.s(30)
            radius: row.s(9)
            color: Qt.rgba(row.theme.surface1.r, row.theme.surface1.g, row.theme.surface1.b, 0.7)

            component StepButton: Item {
                id: btn
                property string glyph: ""
                property int dir: 1
                property bool atLimit: false
                width: row.s(30)
                height: parent ? parent.height : row.s(30)

                Text {
                    anchors.centerIn: parent
                    text: btn.glyph
                    color: btn.atLimit ? row.theme.overlay0
                                       : (ma.containsMouse ? row.theme.mauve : row.theme.subtext0)
                    font.family: "JetBrains Mono"
                    font.weight: Font.Bold
                    font.pixelSize: row.s(15)
                    Behavior on color { ColorAnimation { duration: 180 } }
                    scale: ma.pressed ? 0.78 : 1.0
                    Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 2.4 } }
                }

                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !btn.atLimit
                    cursorShape: btn.atLimit ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: row.bump(btn.dir)
                }
            }

            StepButton {
                anchors.left: parent.left
                glyph: "−"
                dir: -1
                atLimit: row.value <= row.from
            }

            Text {
                anchors.centerIn: parent
                text: String(row.value)
                color: row.theme.text
                font.family: "JetBrains Mono"
                font.weight: Font.DemiBold
                font.pixelSize: row.s(12)
            }

            StepButton {
                anchors.right: parent.right
                glyph: "+"
                dir: 1
                atLimit: row.value >= row.to
            }
        }
    }
}
