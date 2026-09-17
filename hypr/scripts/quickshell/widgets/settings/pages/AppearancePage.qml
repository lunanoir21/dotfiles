import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../parts"
import "../../../core"

// Hyprland'in görünüm/davranış ayarları. Değerler Config'in hypr* property'leri
// üzerinden settings.json'daki "hypr" nesnesine, oradan da settings_watcher.sh
// ile templates/settings.conf.template'e gidiyor.
//
// Her kontrol iki adımlı: sürüklerken previewHyprSetting() çalışan Hyprland'e
// `hyprctl keyword` ile anında uygular, bırakınca queueHyprSave() 450ms debounce
// ile diske yazar. Diske yazmak tam bir `hyprctl reload` tetiklediği için
// sürükleme boyunca yapılamaz.
ColumnLayout {
    id: page

    property var theme
    property real sf: 1.0

    // Bu sayfa kendi kendine kaydediyor, üstteki Kaydet düğmesine ihtiyacı yok.
    readonly property bool hasSave: false
    readonly property bool dirty: false
    function save() {}

    function s(v) { return Math.round(v * page.sf); }

    // ---- Tema -----------------------------------------------------------
    // Tema tek bir yerden uygulanıyor (scripts/theme.sh): quickshell renkleri,
    // Hyprland kenarlıkları ve Dynamic Island'ın kendi paleti aynı anda
    // değişiyor. Burada sadece seçim var; dağıtımı script yapıyor.
    // Mutlak yol: quickshell'in QML kökü scripts/quickshell/, theme.sh ise bir
    // üstteki scripts/ içinde. Qt.resolvedUrl kökün dışına çıkınca kullanılabilir
    // bir dosya yolu üretmiyor ("Module path ... is outside of the config folder").
    readonly property string themeScript: Quickshell.env("HOME") + "/.config/hypr/scripts/theme.sh"

    property var themes: []
    property string themesRaw: ""
    property string activeTheme: "black"
    property string pendingTheme: ""

    Process {
        id: themeList
        stdout: StdioCollector {
            onStreamFinished: {
                // İçerik aynıysa modeli yeniden atama. Her atama Repeater'ın
                // bütün delegate'lerini yıkıp yeniden kuruyor; o sırada devam
                // eden geçiş animasyonları hedefsiz kalıp hata basıyordu.
                const txt = this.text.trim();
                if (txt === "" || txt === page.themesRaw) return;
                page.themesRaw = txt;
                try { page.themes = JSON.parse(txt); } catch (e) {}
            }
        }
    }
    Process {
        id: themeCurrent
        stdout: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim();
                if (t !== "") page.activeTheme = t;
                page.pendingTheme = "";
            }
        }
    }
    Process { id: themeApply; stdout: StdioCollector { onStreamFinished: page.refreshTheme() } }

    function refreshTheme() {
        // Tema listesi diskte sabit; yalnızca ilk kez okunuyor. Etkin tema
        // dışarıdan da değişebildiği için (theme.sh, kısayol) o her seferinde
        // tazeleniyor.
        if (page.themes.length === 0 && !themeList.running) {
            themeList.command = ["bash", "-c", "bash '" + page.themeScript + "' list"];
            themeList.running = true;
        }
        if (!themeCurrent.running) {
            themeCurrent.command = ["bash", "-c", "bash '" + page.themeScript + "' current"];
            themeCurrent.running = true;
        }
    }

    function setTheme(name) {
        if (name === page.activeTheme || themeApply.running) return;
        page.pendingTheme = name;
        themeApply.command = ["bash", "-c", "bash '" + page.themeScript + "' apply '" + name + "'"];
        themeApply.running = true;
    }

    onVisibleChanged: if (visible) page.refreshTheme()
    Component.onCompleted: page.refreshTheme()

    // Tek noktadan: property'yi yaz, canlı önizle, kaydı kuyruğa al.
    function apply(key, prop, value, live) {
        Config[prop] = value;
        if (live) Config.previewHyprSetting(key, value);
        Config.queueHyprSave();
    }

    spacing: s(18)

    SettingCard {
        theme: page.theme
        sf: page.sf
        title: "TEMA"

        Repeater {
                model: page.themes

                delegate: Rectangle {
                    id: themeCard
                    required property var modelData

                    readonly property bool selected: page.activeTheme === themeCard.modelData.name
                    readonly property bool busy: page.pendingTheme === themeCard.modelData.name

                    Layout.fillWidth: true
                    Layout.leftMargin: page.s(8)
                    Layout.rightMargin: page.s(8)
                    Layout.preferredHeight: page.s(60)
                    radius: page.s(13)
                    color: themeCard.selected ? Qt.rgba(page.theme.mauve.r, page.theme.mauve.g, page.theme.mauve.b, 0.16)
                                              : (themeMa.containsMouse
                                                 ? Qt.rgba(page.theme.surface1.r, page.theme.surface1.g, page.theme.surface1.b, 0.7)
                                                 : Qt.rgba(page.theme.surface1.r, page.theme.surface1.g, page.theme.surface1.b, 0.35))
                    border.width: 1
                    border.color: themeCard.selected ? page.theme.mauve
                                                     : Qt.rgba(page.theme.text.r, page.theme.text.g, page.theme.text.b, 0.07)
                    Behavior on color { ColorAnimation { duration: 200 } }
                    Behavior on border.color { ColorAnimation { duration: 200 } }

                    scale: themeMa.pressed ? 0.97 : 1.0
                    Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: page.s(12)
                        anchors.rightMargin: page.s(12)
                        spacing: page.s(11)

                        // Renk lekesi: temanın adını okumadan önce nasıl
                        // göründüğü belli olsun — zemin, yüzey, metin.
                        Rectangle {
                            Layout.preferredWidth: page.s(34)
                            Layout.preferredHeight: page.s(34)
                            radius: page.s(9)
                            color: themeCard.modelData.swatch[0]
                            border.width: 1
                            border.color: Qt.rgba(page.theme.text.r, page.theme.text.g, page.theme.text.b, 0.12)
                            clip: true

                            Rectangle {
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                width: parent.width * 0.55
                                height: parent.height * 0.55
                                radius: page.s(8)
                                color: themeCard.modelData.swatch[1]
                            }
                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.margins: page.s(7)
                                width: page.s(9); height: page.s(9)
                                radius: width / 2
                                color: themeCard.modelData.swatch[2]
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                Layout.fillWidth: true
                                text: themeCard.modelData.label
                                color: page.theme.text
                                font.family: "JetBrains Mono"
                                font.weight: themeCard.selected ? Font.DemiBold : Font.Normal
                                font.pixelSize: page.s(12)
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: themeCard.busy ? "uygulanıyor…" : themeCard.modelData.hint
                                color: themeCard.busy ? page.theme.blue : page.theme.overlay0
                                font.family: "JetBrains Mono"
                                font.pixelSize: page.s(9)
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            text: "󰄬"
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: page.s(14)
                            color: page.theme.mauve
                            opacity: themeCard.selected ? 1 : 0
                            scale: themeCard.selected ? 1 : 0.5
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                            Behavior on scale { NumberAnimation { duration: 360; easing.type: Easing.OutBack; easing.overshoot: 2.6 } }
                        }
                    }

                    MouseArea {
                        id: themeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.setTheme(themeCard.modelData.name)
                    }
                }
        }

        Text {
            Layout.fillWidth: true
            Layout.leftMargin: page.s(14)
            Layout.rightMargin: page.s(14)
            Layout.bottomMargin: page.s(6)
            text: "Tema; üst bar, kenar çubuğu, ayarlar, Dynamic Island ve pencere kenarlıklarının tamamına birden uygulanır."
            color: page.theme.overlay0
            font.family: "JetBrains Mono"
            font.pixelSize: page.s(9)
            wrapMode: Text.WordWrap
        }
    }

    SettingCard {
        theme: page.theme
        sf: page.sf
        title: "PENCERE"

        RowSlider {
            theme: page.theme; sf: page.sf
            label: "İç boşluk"
            hint: "Pencereler arasındaki mesafe (gaps_in)"
            from: 0; to: 40; stepSize: 1
            value: Config.hyprGapsIn
            onMoved: (v) => page.apply("gapsIn", "hyprGapsIn", Math.round(v), true)
            onCommitted: (v) => page.apply("gapsIn", "hyprGapsIn", Math.round(v), true)
        }

        RowSlider {
            theme: page.theme; sf: page.sf
            label: "Dış boşluk"
            hint: "Ekran kenarı ile pencereler arasındaki mesafe (gaps_out)"
            from: 0; to: 60; stepSize: 1
            value: Config.hyprGapsOut
            onMoved: (v) => page.apply("gapsOut", "hyprGapsOut", Math.round(v), true)
            onCommitted: (v) => page.apply("gapsOut", "hyprGapsOut", Math.round(v), true)
        }

        RowSlider {
            theme: page.theme; sf: page.sf
            label: "Yüzen pencere boşluğu"
            hint: "float_gaps"
            from: 0; to: 40; stepSize: 1
            value: Config.hyprFloatGaps
            onMoved: (v) => page.apply("floatGaps", "hyprFloatGaps", Math.round(v), true)
            onCommitted: (v) => page.apply("floatGaps", "hyprFloatGaps", Math.round(v), true)
        }

        RowSpin {
            theme: page.theme; sf: page.sf
            label: "Kenarlık kalınlığı"
            hint: "border_size"
            from: 0; to: 10; step: 1
            value: Config.hyprBorderSize
            onChanged: (v) => page.apply("borderSize", "hyprBorderSize", v, true)
        }

        RowToggle {
            theme: page.theme; sf: page.sf
            label: "Kenardan boyutlandır"
            hint: "Pencere kenarına tıklayıp sürükleyerek boyutlandırma"
            checked: Config.hyprResizeOnBorder
            onToggled: (v) => page.apply("resizeOnBorder", "hyprResizeOnBorder", v, true)
        }
    }

    SettingCard {
        theme: page.theme
        sf: page.sf
        title: "DEKORASYON"

        RowSlider {
            theme: page.theme; sf: page.sf
            label: "Köşe yuvarlaklığı"
            hint: "rounding"
            from: 0; to: 30; stepSize: 1
            value: Config.hyprRounding
            onMoved: (v) => page.apply("rounding", "hyprRounding", Math.round(v), true)
            onCommitted: (v) => page.apply("rounding", "hyprRounding", Math.round(v), true)
        }

        RowSlider {
            theme: page.theme; sf: page.sf
            label: "Aktif pencere saydamlığı"
            from: 0.3; to: 1.0; stepSize: 0.01; decimals: 2
            value: Config.hyprActiveOpacity
            onMoved: (v) => page.apply("activeOpacity", "hyprActiveOpacity", Number(v.toFixed(2)), true)
            onCommitted: (v) => page.apply("activeOpacity", "hyprActiveOpacity", Number(v.toFixed(2)), true)
        }

        RowSlider {
            theme: page.theme; sf: page.sf
            label: "Pasif pencere saydamlığı"
            from: 0.3; to: 1.0; stepSize: 0.01; decimals: 2
            value: Config.hyprInactiveOpacity
            onMoved: (v) => page.apply("inactiveOpacity", "hyprInactiveOpacity", Number(v.toFixed(2)), true)
            onCommitted: (v) => page.apply("inactiveOpacity", "hyprInactiveOpacity", Number(v.toFixed(2)), true)
        }

        RowToggle {
            theme: page.theme; sf: page.sf
            label: "Bulanıklık"
            hint: "Saydam pencerelerin arkasını bulanıklaştır"
            checked: Config.hyprBlurEnabled
            onToggled: (v) => page.apply("blurEnabled", "hyprBlurEnabled", v, true)
        }

        RowSlider {
            theme: page.theme; sf: page.sf
            label: "Bulanıklık yarıçapı"
            hint: Config.hyprBlurEnabled ? "blur:size" : "bulanıklık kapalıyken etkisiz"
            from: 1; to: 30; stepSize: 1
            value: Config.hyprBlurSize
            opacity: Config.hyprBlurEnabled ? 1.0 : 0.45
            Behavior on opacity { NumberAnimation { duration: 220 } }
            onMoved: (v) => page.apply("blurSize", "hyprBlurSize", Math.round(v), true)
            onCommitted: (v) => page.apply("blurSize", "hyprBlurSize", Math.round(v), true)
        }

        RowSpin {
            theme: page.theme; sf: page.sf
            label: "Bulanıklık geçişi"
            hint: "blur:passes — yüksek değer daha yumuşak ama daha pahalı"
            from: 1; to: 6; step: 1
            value: Config.hyprBlurPasses
            opacity: Config.hyprBlurEnabled ? 1.0 : 0.45
            Behavior on opacity { NumberAnimation { duration: 220 } }
            onChanged: (v) => page.apply("blurPasses", "hyprBlurPasses", v, true)
        }

        RowToggle {
            theme: page.theme; sf: page.sf
            label: "Gölge"
            checked: Config.hyprShadowEnabled
            onToggled: (v) => page.apply("shadowEnabled", "hyprShadowEnabled", v, true)
        }
    }

    SettingCard {
        theme: page.theme
        sf: page.sf
        title: "GİRDİ"

        RowSlider {
            theme: page.theme; sf: page.sf
            label: "İmleç hassasiyeti"
            hint: "-1.0 ile 1.0 arası, 0 dokunulmamış hız"
            from: -1.0; to: 1.0; stepSize: 0.05; decimals: 2
            value: Config.hyprSensitivity
            onMoved: (v) => page.apply("sensitivity", "hyprSensitivity", Number(v.toFixed(2)), true)
            onCommitted: (v) => page.apply("sensitivity", "hyprSensitivity", Number(v.toFixed(2)), true)
        }

        RowToggle {
            theme: page.theme; sf: page.sf
            label: "Doğal kaydırma"
            hint: "Touchpad'de içerik parmakla aynı yöne gider"
            checked: Config.hyprNaturalScroll
            onToggled: (v) => page.apply("naturalScroll", "hyprNaturalScroll", v, true)
        }
    }

    SettingCard {
        theme: page.theme
        sf: page.sf
        title: "YAZI TİPİ & ANİMASYON"

        RowText {
            theme: page.theme; sf: page.sf
            label: "Yazı tipi"
            hint: "Hyprland'in kendi arayüzü için (misc:font_family)"
            placeholder: "JetBrains Mono"
            value: Config.hyprFontFamily
            onEdited: (v) => page.apply("fontFamily", "hyprFontFamily", v, true)
        }

        RowToggle {
            theme: page.theme; sf: page.sf
            label: "Animasyonlar"
            checked: Config.hyprAnimationsEnabled
            onToggled: (v) => page.apply("animationsEnabled", "hyprAnimationsEnabled", v, true)
        }

        RowSlider {
            theme: page.theme; sf: page.sf
            // animSpeed tek bir hyprctl keyword'e karşılık gelmiyor (dokuz ayrı
            // animation satırına yayılıyor), o yüzden canlı önizleme yok:
            // değer ancak yeniden derlemeden sonra görünür.
            label: "Animasyon süresi"
            hint: "Yüksek değer = daha yavaş. Yeniden derlemeden sonra uygulanır."
            from: 1; to: 20; stepSize: 1
            value: Config.hyprAnimSpeed
            opacity: Config.hyprAnimationsEnabled ? 1.0 : 0.45
            Behavior on opacity { NumberAnimation { duration: 220 } }
            onMoved: (v) => Config.hyprAnimSpeed = Math.round(v)
            onCommitted: (v) => page.apply("animSpeed", "hyprAnimSpeed", Math.round(v), false)
        }
    }
}
