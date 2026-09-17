pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

// Açılır seçim satırı. Popup yerine satırın altında yerinde genişleyen liste:
// bu satırlar bir Flickable içinde yaşıyor ve orada popup'lar z-sırası ile
// kırpma sorunu çıkarıyor (Segmented.qml'de aynı gerekçe).
//
// Segmented kısa listeler için; bu, seçenekler uzun ya da sayıları
// değişkense (ses cihazları, çözünürlükler) doğru olan.
Item {
    id: row

    property var theme
    property real sf: 1.0
    property string label: ""
    property string hint: ""
    property var options: []        // [{ value, label, detail }] ya da düz string dizisi
    property string currentValue: ""
    property string placeholder: "Seçilmedi"
    property bool open: false

    signal picked(string value)

    function s(v) { return Math.round(v * row.sf); }

    function optValue(o) { return (typeof o === "string") ? o : o.value; }
    function optLabel(o) { return (typeof o === "string") ? o : (o.label || o.value); }
    function optDetail(o) { return (typeof o === "string") ? "" : (o.detail || ""); }

    readonly property string currentLabel: {
        for (let i = 0; i < row.options.length; i++) {
            if (row.optValue(row.options[i]) === row.currentValue)
                return row.optLabel(row.options[i]);
        }
        return row.placeholder;
    }

    Layout.fillWidth: true
    implicitHeight: header.height + listWrap.height

    Item {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: row.hint !== "" ? row.s(58) : row.s(44)

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: row.s(4)
            anchors.rightMargin: row.s(4)
            radius: row.s(10)
            color: (headMa.containsMouse || row.open)
                   ? Qt.rgba(row.theme.surface1.r, row.theme.surface1.g, row.theme.surface1.b, 0.45)
                   : "transparent"
            Behavior on color { ColorAnimation { duration: 200 } }
        }

        MouseArea {
            id: headMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.open = !row.open
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

            Text {
                text: row.currentLabel
                color: row.currentValue === "" ? row.theme.overlay0 : row.theme.mauve
                font.family: "JetBrains Mono"
                font.pixelSize: row.s(11)
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                Layout.maximumWidth: row.width * 0.42
            }

            Text {
                text: "󰅀"
                font.family: "Iosevka Nerd Font"
                font.pixelSize: row.s(10)
                color: row.theme.overlay0
                rotation: row.open ? 180 : 0
                Behavior on rotation { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
            }
        }
    }

    Item {
        id: listWrap
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        clip: true

        property real openH: row.open ? listCol.implicitHeight + row.s(6) : 0
        Behavior on openH { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        height: openH
        opacity: row.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        ColumnLayout {
            id: listCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: row.s(14)
            anchors.rightMargin: row.s(14)
            spacing: row.s(3)

            Repeater {
                model: row.options

                delegate: Rectangle {
                    id: opt
                    required property int index
                    required property var modelData

                    readonly property bool selected: row.optValue(opt.modelData) === row.currentValue

                    Layout.fillWidth: true
                    Layout.preferredHeight: row.optDetail(opt.modelData) !== "" ? row.s(42) : row.s(32)
                    radius: row.s(9)
                    color: opt.selected
                           ? Qt.rgba(row.theme.mauve.r, row.theme.mauve.g, row.theme.mauve.b, 0.18)
                           : (optMa.containsMouse
                              ? Qt.rgba(row.theme.surface2.r, row.theme.surface2.g, row.theme.surface2.b, 0.55)
                              : Qt.rgba(row.theme.surface1.r, row.theme.surface1.g, row.theme.surface1.b, 0.35))
                    border.width: 1
                    border.color: opt.selected ? row.theme.mauve : "transparent"
                    Behavior on color { ColorAnimation { duration: 180 } }
                    Behavior on border.color { ColorAnimation { duration: 180 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: row.s(11)
                        anchors.rightMargin: row.s(11)
                        spacing: row.s(8)

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                Layout.fillWidth: true
                                text: row.optLabel(opt.modelData)
                                color: opt.selected ? row.theme.text : row.theme.subtext0
                                font.family: "JetBrains Mono"
                                font.pixelSize: row.s(11)
                                font.weight: opt.selected ? Font.DemiBold : Font.Normal
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: row.optDetail(opt.modelData) !== ""
                                text: row.optDetail(opt.modelData)
                                color: row.theme.overlay0
                                font.family: "JetBrains Mono"
                                font.pixelSize: row.s(9)
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            text: "󰄬"
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: row.s(12)
                            color: row.theme.mauve
                            opacity: opt.selected ? 1 : 0
                            scale: opt.selected ? 1 : 0.5
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                            Behavior on scale { NumberAnimation { duration: 340; easing.type: Easing.OutBack; easing.overshoot: 2.4 } }
                        }
                    }

                    MouseArea {
                        id: optMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            row.picked(row.optValue(opt.modelData));
                            row.open = false;
                        }
                    }
                }
            }
        }
    }
}
