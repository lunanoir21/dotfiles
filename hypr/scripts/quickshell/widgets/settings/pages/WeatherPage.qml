import QtQuick
import QtQuick.Layouts
import "../parts"
import "../../../core"

ColumnLayout {
    id: page

    property var theme
    property real sf: 1.0

    readonly property bool hasSave: true
    property bool dirty: false
    function save() {
        Config.saveWeatherConfig();
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
        title: "OPENWEATHER"

        RowText {
            theme: page.theme; sf: page.sf
            label: "API anahtarı"
            hint: "openweathermap.org üzerinden ücretsiz alınır"
            placeholder: "32 karakterlik anahtar"
            value: Config.weatherApiKey
            onEdited: (v) => page.touch("weatherApiKey", v)
        }

        RowText {
            theme: page.theme; sf: page.sf
            label: "Şehir ID"
            hint: "OpenWeather'ın sayısal şehir kimliği"
            placeholder: "745044"
            value: Config.weatherCityId
            onEdited: (v) => page.touch("weatherCityId", v)
        }

        RowToggle {
            theme: page.theme; sf: page.sf
            label: "Fahrenheit kullan"
            hint: "Kapalıyken Celsius (metric)"
            checked: Config.weatherUnit === "imperial"
            onToggled: (v) => page.touch("weatherUnit", v ? "imperial" : "metric")
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.leftMargin: page.s(4)
        text: "Kaydedildiğinde hava durumu önbelleği temizlenir ve veri yeniden çekilir."
        color: page.theme.overlay0
        font.family: "JetBrains Mono"
        font.pixelSize: page.s(10)
        wrapMode: Text.WordWrap
    }
}
