import QtQuick
import QtQuick.Layouts
import "../parts"
import "../../../core"

ColumnLayout {
    id: page

    property var theme
    property real sf: 1.0

    // Bu sayfa doğrudan settings.json'un kök anahtarlarını yazıyor ve yazım
    // Hyprland'i yeniden yüklüyor — o yüzden otomatik değil, açık Kaydet ile.
    readonly property bool hasSave: true
    property bool dirty: false
    function save() {
        Config.saveAppSettings();
        page.dirty = false;
    }

    function s(v) { return Math.round(v * page.sf); }
    function touch(prop, value) {
        Config[prop] = value;
        page.dirty = true;
    }

    spacing: s(18)

    SettingCard {
        theme: page.theme
        sf: page.sf
        title: "ARAYÜZ"

        RowSlider {
            theme: page.theme; sf: page.sf
            label: "Arayüz ölçeği"
            hint: "Tüm quickshell widget'larının boyutu"
            from: 0.5; to: 2.0; stepSize: 0.05; decimals: 2
            value: Config.uiScale
            onMoved: (v) => page.touch("uiScale", Number(v.toFixed(2)))
            onCommitted: (v) => page.touch("uiScale", Number(v.toFixed(2)))
        }

        RowSpin {
            theme: page.theme; sf: page.sf
            label: "Çalışma alanı sayısı"
            hint: "Kaydedildiğinde üst bar yeniden yüklenir"
            from: 2; to: 10; step: 1
            value: Config.workspaceCount
            onChanged: (v) => page.touch("workspaceCount", v)
        }
    }

    SettingCard {
        theme: page.theme
        sf: page.sf
        title: "KLAVYE"

        RowText {
            theme: page.theme; sf: page.sf
            label: "Klavye düzeni"
            hint: "Virgülle birden fazla: us,tr"
            placeholder: "us"
            value: Config.language
            onEdited: (v) => page.touch("language", v)
        }

        RowText {
            theme: page.theme; sf: page.sf
            label: "Klavye seçenekleri"
            hint: "kb_options — örn. grp:alt_shift_toggle"
            placeholder: "grp:alt_shift_toggle"
            value: Config.kbOptions
            onEdited: (v) => page.touch("kbOptions", v)
        }
    }

    SettingCard {
        theme: page.theme
        sf: page.sf
        title: "DUVAR KAĞIDI"

        RowText {
            theme: page.theme; sf: page.sf
            label: "Duvar kağıdı klasörü"
            hint: "Duvar kağıdı seçicinin taradığı dizin"
            placeholder: "~/Pictures/Wallpapers"
            value: Config.wallpaperDir
            onEdited: (v) => page.touch("wallpaperDir", v)
        }
    }
}
