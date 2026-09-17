import QtQuick
import QtQuick.Layouts
import "../../../core"

// Bir arama sonucu. İki biçimi var:
//
//   kind "setting" -> ayarın KENDİSİ burada çizilir. Kullanıcı sonucu görüp
//                     sayfaya gitmeden, olduğu yerde değeri değiştirir.
//                     Ayarın nerede yaşadığı üstteki iz (Görünüm › Dekorasyon)
//                     ile söyleniyor; oraya gitmek isteyen tıklar.
//
//   kind "page"    -> tek değere indirgenemeyen alanlar (Ağ, Monitörler).
//                     Sonuç kullanıcıyı sayfaya götüren bir karttır.
Item {
    id: res

    property var theme
    property real sf: 1.0
    property var result: null       // SettingsIndex.search() çıktısındaki bir öğe
    property bool active: false     // klavyeyle seçili

    signal changed(var entry, var value)
    signal openPage(string page)

    function s(v) { return Math.round(v * res.sf); }

    readonly property string kind: res.result ? res.result.kind : ""
    readonly property var entry: (res.result && res.result.kind === "setting") ? res.result.entry : null
    readonly property var hintData: (res.result && res.result.kind === "page") ? res.result.hint : null

    readonly property var pageNames: ({
        appearance: "Görünüm", widgets: "Widget'lar", general: "Genel", weather: "Hava",
        network: "Ağ", bluetooth: "Bluetooth", audio: "Ses", power: "Güç & pil",
        keybinds: "Kısayollar", monitors: "Monitörler", startup: "Başlangıç"
    })

    Layout.fillWidth: true
    implicitHeight: card.implicitHeight

    Rectangle {
        id: card
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        implicitHeight: inner.implicitHeight + res.s(10)
        radius: res.s(14)
        color: res.active
               ? Qt.rgba(res.theme.surface1.r, res.theme.surface1.g, res.theme.surface1.b, 0.6)
               : Qt.rgba(res.theme.surface0.r, res.theme.surface0.g, res.theme.surface0.b, 0.5)
        border.width: 1
        border.color: res.active
                      ? res.theme.mauve
                      : Qt.rgba(res.theme.text.r, res.theme.text.g, res.theme.text.b, 0.06)
        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on border.color { ColorAnimation { duration: 180 } }

        ColumnLayout {
            id: inner
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: res.s(5)
            spacing: 0

            // --- konum izi: ayarın hangi sayfada yaşadığı ---
            RowLayout {
                visible: res.kind === "setting"
                Layout.fillWidth: true
                Layout.leftMargin: res.s(15)
                Layout.rightMargin: res.s(12)
                Layout.topMargin: res.s(3)
                spacing: res.s(5)

                Text {
                    text: res.entry ? (res.pageNames[res.entry.page] || res.entry.page) : ""
                    color: res.theme.mauve
                    font.family: "JetBrains Mono"
                    font.pixelSize: res.s(9)
                    font.weight: Font.DemiBold
                }
                Text {
                    visible: res.entry && res.entry.card !== undefined && res.entry.card !== ""
                    text: "›"
                    color: res.theme.overlay0
                    font.family: "JetBrains Mono"
                    font.pixelSize: res.s(9)
                }
                Text {
                    text: res.entry ? (res.entry.card || "") : ""
                    color: res.theme.overlay0
                    font.family: "JetBrains Mono"
                    font.pixelSize: res.s(9)
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "sayfaya git 󰅂"
                    color: crumbMa.containsMouse ? res.theme.mauve : res.theme.overlay0
                    font.family: "JetBrains Mono"
                    font.pixelSize: res.s(9)
                    Behavior on color { ColorAnimation { duration: 180 } }

                    MouseArea {
                        id: crumbMa
                        anchors.fill: parent
                        anchors.margins: -res.s(5)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (res.entry) res.openPage(res.entry.page)
                    }
                }
            }

            // --- ayarın canlı kontrolü ---
            Loader {
                Layout.fillWidth: true
                active: res.kind === "setting"
                visible: active
                sourceComponent: {
                    if (!res.entry) return null;
                    switch (res.entry.type) {
                        case "toggle": return toggleC;
                        case "slider": return sliderC;
                        case "spin":   return spinC;
                        case "text":   return textC;
                        case "select": return selectC;
                    }
                    return null;
                }
            }

            // --- sayfa kartı ---
            Loader {
                Layout.fillWidth: true
                active: res.kind === "page"
                visible: active
                sourceComponent: pageC
            }
        }
    }

    // ------------------------------------------------------------------
    // Tip başına kontrol. Hepsi sayfalardaki ile aynı bileşen — arama sonucu
    // "ayarın bir kopyası" değil, ayarın kendisi gibi davransın diye.
    // ------------------------------------------------------------------
    Component {
        id: toggleC
        RowToggle {
            theme: res.theme; sf: res.sf
            label: res.entry.label
            hint: res.entry.hint || ""
            checked: res.entry
                ? (res.entry.invert ? Config[res.entry.prop] !== true
                                    : Config[res.entry.prop] === true)
                : false
            onToggled: (v) => res.changed(res.entry, res.entry.invert ? !v : v)
        }
    }

    Component {
        id: sliderC
        RowSlider {
            theme: res.theme; sf: res.sf
            label: res.entry.label
            hint: res.entry.hint || ""
            from: res.entry.min; to: res.entry.max
            stepSize: res.entry.step; decimals: res.entry.decimals || 0
            suffix: res.entry.suffix || ""
            value: res.entry ? Config[res.entry.prop] : 0
            onMoved: (v) => res.changed(res.entry, res.entry.decimals > 0 ? Number(v.toFixed(res.entry.decimals)) : Math.round(v))
            onCommitted: (v) => res.changed(res.entry, res.entry.decimals > 0 ? Number(v.toFixed(res.entry.decimals)) : Math.round(v))
        }
    }

    Component {
        id: spinC
        RowSpin {
            theme: res.theme; sf: res.sf
            label: res.entry.label
            hint: res.entry.hint || ""
            from: res.entry.min; to: res.entry.max; step: res.entry.step
            value: res.entry ? Config[res.entry.prop] : 0
            onChanged: (v) => res.changed(res.entry, v)
        }
    }

    Component {
        id: textC
        RowText {
            theme: res.theme; sf: res.sf
            label: res.entry.label
            hint: res.entry.hint || ""
            placeholder: res.entry.placeholder || ""
            value: res.entry ? String(Config[res.entry.prop]) : ""
            onEdited: (v) => res.changed(res.entry, v)
        }
    }

    Component {
        id: selectC
        RowSelect {
            theme: res.theme; sf: res.sf
            label: res.entry.label
            hint: res.entry.hint || ""
            options: res.entry.options || []
            currentValue: res.entry ? String(Config[res.entry.prop]) : ""
            onPicked: (v) => res.changed(res.entry, v)
        }
    }

    Component {
        id: pageC
        RowNav {
            theme: res.theme; sf: res.sf
            icon: res.hintData ? res.hintData.icon : ""
            label: res.hintData ? res.hintData.label : ""
            hint: res.hintData ? res.hintData.hint : ""
            onActivated: if (res.hintData) res.openPage(res.hintData.page)
        }
    }
}
