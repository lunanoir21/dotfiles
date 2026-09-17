import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: row

    property var theme
    property real sf: 1.0
    property string label: ""
    property string hint: ""
    property string value: ""
    property string placeholder: ""
    property real fieldWidth: 0   // 0 = kalan genişliği doldur

    signal edited(string v)

    function s(v) { return Math.round(v * row.sf); }

    Layout.fillWidth: true
    implicitHeight: row.hint !== "" ? s(60) : s(46)

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: row.s(14)
        anchors.rightMargin: row.s(14)
        spacing: row.s(12)

        ColumnLayout {
            Layout.fillWidth: true
            Layout.maximumWidth: row.width * 0.4
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

        TextField {
            id: field
            Layout.fillWidth: row.fieldWidth <= 0
            Layout.preferredWidth: row.fieldWidth > 0 ? row.s(row.fieldWidth) : -1
            Layout.preferredHeight: row.s(32)

            // value'ya binding kurulmuyor: kullanıcı yazmaya başladığı anda
            // binding kopar ve alan bir daha dışarıdan tazelenmezdi.
            Component.onCompleted: text = row.value

            placeholderText: row.placeholder
            color: row.theme.text
            placeholderTextColor: row.theme.overlay0
            font.family: "JetBrains Mono"
            font.pixelSize: row.s(11)
            selectByMouse: true
            leftPadding: row.s(10)
            rightPadding: row.s(10)

            background: Rectangle {
                radius: row.s(9)
                color: Qt.rgba(row.theme.surface1.r, row.theme.surface1.g, row.theme.surface1.b, 0.7)
                border.width: 1
                border.color: field.activeFocus
                              ? row.theme.mauve
                              : Qt.rgba(row.theme.text.r, row.theme.text.g, row.theme.text.b, 0.08)
                Behavior on border.color { ColorAnimation { duration: 200 } }
            }

            onEditingFinished: if (text !== row.value) row.edited(text)
        }
    }

    Connections {
        target: row
        function onValueChanged() {
            if (!field.activeFocus) field.text = row.value;
        }
    }
}
