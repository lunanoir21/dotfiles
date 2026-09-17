pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../parts"

// Ses: çıkış ve giriş cihazlarının seçimi ve seviyeleri.
//
// Sidebar'daki ses kaydırıcısı yalnızca varsayılan cihazın seviyesini
// ayarlıyor; buraya gelmenin sebebi genelde "sesi hangi cihazdan alacağım"
// sorusu, o yüzden cihaz listesi seviyelerden önce geliyor.
ColumnLayout {
    id: page

    property var theme
    property real sf: 1.0

    readonly property bool hasSave: false
    readonly property bool dirty: false
    function save() {}

    function s(v) { return Math.round(v * page.sf); }
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }

    readonly property string script: Qt.resolvedUrl("../system/audio.sh").toString().replace(/^file:\/\//, "")

    property var st: ({ sinks: [], sources: [] })

    // Sürükleme sırasında poll'un değeri geri almasını engelliyor: kullanıcı
    // kaydırırken gelen bir status cevabı slider'ı zıplatırdı.
    property bool sliding: false

    readonly property var defaultSink: {
        for (let i = 0; i < page.st.sinks.length; i++)
            if (page.st.sinks[i].default) return page.st.sinks[i];
        return null;
    }
    readonly property var defaultSource: {
        for (let i = 0; i < page.st.sources.length; i++)
            if (page.st.sources[i].default) return page.st.sources[i];
        return null;
    }

    Process {
        id: statusProc
        stdout: StdioCollector {
            onStreamFinished: {
                if (page.sliding) return;
                try { page.st = JSON.parse(this.text.trim()); } catch (e) {}
            }
        }
    }

    function refresh() {
        if (statusProc.running) return;
        statusProc.command = ["bash", "-c", "bash '" + page.script + "' status"];
        statusProc.running = true;
    }

    Process { id: actionProc; stdout: StdioCollector { onStreamFinished: page.refresh() } }

    function run(action, value) {
        let cmd = "bash '" + page.script + "' " + action;
        if (value !== undefined && value !== "") cmd += " '" + value + "'";
        actionProc.command = ["bash", "-c", cmd];
        actionProc.running = true;
    }

    // Seviye kaydırılırken her adımda süreç açmak saniyede onlarca fork
    // demek; kısa bir debounce hem akıcı hem ucuz.
    property int pendingSinkVol: -1
    property int pendingSourceVol: -1
    Timer {
        id: volDebounce
        interval: 70
        onTriggered: {
            if (page.pendingSinkVol >= 0) {
                Quickshell.execDetached(["bash", "-c",
                    "bash '" + page.script + "' sink-volume " + page.pendingSinkVol]);
                page.pendingSinkVol = -1;
            }
            if (page.pendingSourceVol >= 0) {
                Quickshell.execDetached(["bash", "-c",
                    "bash '" + page.script + "' source-volume " + page.pendingSourceVol]);
                page.pendingSourceVol = -1;
            }
        }
    }

    Timer {
        interval: 4000
        repeat: true
        running: page.visible
        triggeredOnStart: true
        onTriggered: page.refresh()
    }

    function deviceIcon(label, isInput) {
        const n = String(label).toLowerCase();
        if (isInput) return /webcam|usb|kamera/.test(n) ? "󰖠" : "󰍬";
        if (/hdmi|displayport/.test(n)) return "󰡁";
        if (/head|kulak|buds/.test(n)) return "󰋋";
        if (/bluetooth/.test(n)) return "󰂰";
        return "󰓃";
    }

    spacing: s(18)

    // ---------------------------------------------------------------
    // Çıkış
    // ---------------------------------------------------------------
    SettingCard {
        theme: page.theme
        sf: page.sf
        title: "ÇIKIŞ"

        EmptyState {
            visible: page.st.sinks.length === 0
            theme: page.theme; sf: page.sf
            icon: "󰓄"
            headline: "Çıkış cihazı bulunamadı"
            body: "PipeWire çalışmıyor olabilir. Sistem ses sunucusunu kontrol edin."
        }

        Repeater {
            model: page.st.sinks

            delegate: RowDevice {
                required property var modelData

                theme: page.theme; sf: page.sf
                icon: page.deviceIcon(modelData.label, false)
                name: modelData.label
                detail: modelData.detail
                connected: modelData.default
                status: modelData.default ? "varsayılan" : ""
                statusTone: page.theme.green
                expanded: false
                onClicked: if (!modelData.default) page.run("set-sink", modelData.id)
            }
        }

        RowSlider {
            theme: page.theme; sf: page.sf
            label: "Ses seviyesi"
            hint: page.defaultSink ? page.defaultSink.label : "Varsayılan cihaz"
            from: 0; to: 150; stepSize: 1; suffix: "%"
            value: page.defaultSink ? page.defaultSink.volume : 0
            onMoved: (v) => {
                page.sliding = true;
                page.pendingSinkVol = Math.round(v);
                volDebounce.restart();
            }
            onCommitted: (v) => {
                page.pendingSinkVol = Math.round(v);
                volDebounce.restart();
                page.sliding = false;
            }
        }

        RowToggle {
            theme: page.theme; sf: page.sf
            label: "Sustur"
            hint: "Çıkış sesini tamamen kapatır"
            checked: page.defaultSink ? page.defaultSink.muted : false
            onToggled: page.run("sink-mute")
        }
    }

    // ---------------------------------------------------------------
    // Giriş
    // ---------------------------------------------------------------
    SettingCard {
        theme: page.theme
        sf: page.sf
        title: "GİRİŞ"

        EmptyState {
            visible: page.st.sources.length === 0
            theme: page.theme; sf: page.sf
            icon: "󰍭"
            headline: "Mikrofon bulunamadı"
            body: "Bağlı bir giriş cihazı görünmüyor."
        }

        Repeater {
            model: page.st.sources

            delegate: RowDevice {
                required property var modelData

                theme: page.theme; sf: page.sf
                icon: page.deviceIcon(modelData.label, true)
                name: modelData.label
                detail: modelData.detail
                connected: modelData.default
                status: modelData.default ? "varsayılan" : ""
                statusTone: page.theme.green
                expanded: false
                onClicked: if (!modelData.default) page.run("set-source", modelData.id)
            }
        }

        RowSlider {
            theme: page.theme; sf: page.sf
            label: "Mikrofon seviyesi"
            hint: page.defaultSource ? page.defaultSource.label : "Varsayılan cihaz"
            from: 0; to: 150; stepSize: 1; suffix: "%"
            value: page.defaultSource ? page.defaultSource.volume : 0
            onMoved: (v) => {
                page.sliding = true;
                page.pendingSourceVol = Math.round(v);
                volDebounce.restart();
            }
            onCommitted: (v) => {
                page.pendingSourceVol = Math.round(v);
                volDebounce.restart();
                page.sliding = false;
            }
        }

        RowToggle {
            theme: page.theme; sf: page.sf
            label: "Mikrofonu sustur"
            hint: "Giriş sesini kapatır"
            checked: page.defaultSource ? page.defaultSource.muted : false
            onToggled: page.run("source-mute")
        }
    }
}
