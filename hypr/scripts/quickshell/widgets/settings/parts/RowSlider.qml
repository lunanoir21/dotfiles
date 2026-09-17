import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

// İki ayrı sinyal veriyor:
//   moved     -> sürükleme boyunca her adımda (anlık önizleme için)
//   committed -> bırakıldığında bir kez (diske yazmak için)
// Ayrım önemli: diske her yazım settings_watcher'ı ve tam bir `hyprctl reload`u
// tetikliyor, bunu sürükleme boyunca yapmak saniyede onlarca reload demek.
Item {
    id: row

    property var theme
    property real sf: 1.0
    property string label: ""
    property string hint: ""
    property real from: 0
    property real to: 100
    property real stepSize: 1
    property real value: 0
    property int decimals: 0
    property string suffix: ""

    signal moved(real v)
    signal committed(real v)

    function s(v) { return Math.round(v * row.sf); }
    function fmt(v) {
        return (row.decimals > 0 ? Number(v).toFixed(row.decimals) : String(Math.round(v))) + row.suffix;
    }

    Layout.fillWidth: true
    implicitHeight: row.hint !== "" ? s(66) : s(52)

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: row.s(14)
        anchors.rightMargin: row.s(14)
        anchors.topMargin: row.s(6)
        anchors.bottomMargin: row.s(6)
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            spacing: row.s(10)

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

            Text {
                text: row.fmt(sl.value)
                color: row.theme.mauve
                font.family: "JetBrains Mono"
                font.weight: Font.DemiBold
                font.pixelSize: row.s(11)
                horizontalAlignment: Text.AlignRight
                Layout.preferredWidth: row.s(52)
            }
        }

        Slider {
            id: sl
            Layout.fillWidth: true
            implicitHeight: row.s(20)
            from: row.from
            to: row.to
            stepSize: row.stepSize

            // value'yu row.value'ya BAĞLAMIYORUZ: kullanıcı sürükleyince Slider
            // kendi value'sunu yazar ve binding kopar, sonrasında dışarıdan gelen
            // güncellemeler bir daha görünmezdi. Bunun yerine tek yön besliyoruz.
            Component.onCompleted: value = row.value

            onMoved: row.moved(sl.value)
            onPressedChanged: if (!pressed) row.committed(sl.value)

            background: Rectangle {
                x: sl.leftPadding
                y: sl.topPadding + sl.availableHeight / 2 - height / 2
                width: sl.availableWidth
                height: row.s(6)
                radius: height / 2
                color: Qt.rgba(row.theme.surface2.r, row.theme.surface2.g, row.theme.surface2.b, 0.7)

                Rectangle {
                    width: sl.visualPosition * parent.width
                    height: parent.height
                    radius: parent.radius
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: row.theme.mauve }
                        GradientStop { position: 1.0; color: row.theme.pink }
                    }
                    Behavior on width { enabled: !sl.pressed; NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                }
            }

            handle: Rectangle {
                x: sl.leftPadding + sl.visualPosition * (sl.availableWidth - width)
                y: sl.topPadding + sl.availableHeight / 2 - height / 2
                width: row.s(15)
                height: width
                radius: width / 2
                color: row.theme.text
                scale: sl.pressed ? 1.35 : (sl.hovered ? 1.15 : 1.0)
                Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 2.6 } }
                Behavior on x { enabled: !sl.pressed; NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            }
        }
    }

    // Dışarıdan (örn. Sıfırla) gelen değişiklik, kullanıcı o an sürüklemiyorsa
    // slider'a yansır.
    Connections {
        target: row
        function onValueChanged() {
            if (!sl.pressed) sl.value = row.value;
        }
    }
}
