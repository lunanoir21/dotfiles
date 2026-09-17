//@ pragma UseQApplication
import QtQuick
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Pipewire
import "../../core"
// Fader.qml ayni klasorde ama Quickshell ayni-klasor cozumlemesi yapmiyor:
// klasorun bir modul olarak taranmasi icin adiyla import edilmesi gerekiyor
// (Shell.qml'in "dock" / "dynamic-island" klasorlerini import etmesi gibi).
// Aksi halde "Fader is not a type" hatasi aliniyor.
import "../mixer" as Mixer

// Ses karıştırıcı: uygulama başına dikey ekolayzer sürgüleri.
//
// Neden pactl değil de Pipewire servisi: uygulama listesi ve ses seviyeleri
// canlı property olarak geliyor, saniyede bir `pactl -f json list` çalıştırıp
// JSON ayrıştırmaya gerek kalmıyor; sürgüyü sürüklerken de shell round-trip
// gecikmesi olmadan anında uygulanıyor.
Item {
    id: window
    focus: true

    Scaler {
        id: scaler
        currentWidth: Screen.width
        currentHeight: Screen.height
    }
    function s(val) { return scaler.s(val); }

    MatugenColors { id: _theme }

    property real layoutWidth: width
    property real layoutHeight: height

    // Main.qml her widget'a bu ikisini geciyor. Burada kullanilmiyorlar ama
    // tanimli olmazlarsa StackView.replace "non-existent property" hatasi atiyor.
    property var notifModel: null
    property var liveNotifs: null

    readonly property real maxVolume: 1.5

    // --- olculer -------------------------------------------------------
    // Panel sabit genislikte degil: acik uygulama sayisina gore buyuyup
    // kuculuyor. Tek uygulama varken 900px'lik bir kutunun ucte ikisinin
    // bos durmasi, panelin ne kadar dolu oldugunu yalan soyluyordu.
    readonly property real stripWidth:  s(112)
    readonly property real stripGap:    s(6)
    readonly property real edgePad:     s(14)
    readonly property real dividerGap:  s(10)

    // Baslik satirinin (isim + kisayol ipuclari) sigmasi icin alt sinir.
    readonly property real minPanelWidth: s(600)

    readonly property real streamsWidth:
        streamNodes.length === 0
            ? s(230)
            : streamNodes.length * stripWidth + (streamNodes.length - 1) * stripGap

    readonly property real desiredWidth:
        edgePad * 2 + stripWidth + dividerGap * 2 + 1 + streamsWidth

    readonly property real panelWidth:
        Math.min(layoutWidth, Math.max(minPanelWidth, desiredWidth))

    // =========================================================
    // KAYNAK: pipewire düğümleri
    // =========================================================
    readonly property var sinkNode: Pipewire.defaultAudioSink

    // Oynatma akışları: isStream + isSink (uygulamadan hoparlöre giden yön).
    // Kayıt akışları (mikrofon okuyanlar) bu panelin konusu değil.
    readonly property var streamNodes: {
        if (!Pipewire.ready) return [];
        let out = [];
        let all = Pipewire.nodes.values;
        for (let i = 0; i < all.length; i++) {
            let n = all[i];
            if (!n) continue;
            // isStream + isSink = PwNodeType.AudioOutStream, yani uygulamadan
            // hoparlore giden akis. `ready` burada kontrol EDILMEZ: bir dugum
            // ancak PwObjectTracker onu bagladiktan sonra ready oluyor, listeyi
            // ready'ye gore suzersek dugum hicbir zaman listeye girmedigi icin
            // hicbir zaman baglanmiyor. Isim/simge ozellikleri sonradan gelir.
            if (!n.isStream || !n.isSink) continue;
            if (!n.audio) continue;
            out.push(n);
        }
        return out;
    }

    // Tracker olmadan volume/muted güncellemeleri gelmiyor: pipewire bu
    // düğümleri sadece biri "bind" ettiğinde canlı yayınlıyor.
    readonly property var trackedNodes: {
        let a = window.streamNodes.slice();
        if (window.sinkNode) a.push(window.sinkNode);
        return a;
    }

    PwObjectTracker { objects: window.trackedNodes }

    // =========================================================
    // İSİM / SİMGE ÇÖZÜMLEME
    // =========================================================
    function propOf(node, key) {
        if (!node || !node.properties) return "";
        let v = node.properties[key];
        return v === undefined || v === null ? "" : String(v);
    }

    function streamName(node) {
        let n = propOf(node, "application.name");
        if (n === "") n = propOf(node, "application.process.binary");
        if (n === "") n = node && node.nickname ? node.nickname : "";
        if (n === "") n = node && node.description ? node.description : "";
        if (n === "") n = node && node.name ? node.name : "Bilinmeyen";
        return n;
    }

    // media.name genelde "Playback" gibi işe yaramaz bir sabit; öyleyse
    // alt satırı boş bırakmak, aynı kelimeyi her sütunda tekrarlamaktan iyi.
    function streamDetail(node) {
        let m = propOf(node, "media.name");
        if (m === "" ) return "";
        // Uygulamalarin cogu media.name alanina calan seyin adini degil,
        // "Playback" / "AudioStream" gibi sabit bir etiket koyuyor. Bunlari
        // her sutunun altinda tekrarlamak yer kaplamaktan baska ise yaramiyor.
        let low = m.toLowerCase().replace(/[ _-]/g, "");
        let generic = ["playback", "audiostream", "playstream", "capture",
                       "output", "stream", "sink", "audio"];
        for (let i = 0; i < generic.length; i++) {
            if (low === generic[i]) return "";
        }
        if (m === streamName(node)) return "";
        return m;
    }

    // DesktopEntries tembel yukleniyor: listeye ilk erisim taramayi baslatiyor,
    // sonuclar ~1 sn sonra geliyor. Bu property hem taramayi panel acilir
    // acilmaz tetikliyor hem de resolveIcon baglantilarinin liste dolunca
    // yeniden degerlenmesini sagliyor (fonksiyon icinden okundugu icin QML
    // bagimliligi yakaliyor).
    readonly property int desktopEntryCount: DesktopEntries.applications.values.length

    function normKey(s) {
        return String(s || "").toLowerCase().trim().replace(/[ _]+/g, "-");
    }

    // DesktopEntries.heuristicLookup() bu Quickshell surumunde her sey icin
    // null donuyor, o yuzden eslestirmeyi kendimiz yapiyoruz. Sira gevsekten
    // degil, en kesin eslesmeden basliyor ki "Element" yanlislikla
    // "element-desktop-nightly" gibi bir girdiye baglanmasin.
    function findEntry(name) {
        let key = normKey(name);
        if (key === "") return null;

        let apps = DesktopEntries.applications.values;
        let byLastSegment = null, byExec = null, byPrefix = null;

        for (let i = 0; i < apps.length; i++) {
            let a = apps[i];
            let id = normKey(a.id);
            let nm = normKey(a.name);

            if (id === key || nm === key) return a;

            // "io.element.Element" -> "element"
            if (!byLastSegment && id.split(".").pop() === key) byLastSegment = a;

            if (!byExec) {
                let ex = normKey(String(a.execString || "").split(" ")[0].split("/").pop());
                if (ex !== "" && ex === key) byExec = a;
            }

            // Serbest "icerir" eslesmesi cok gevsek: "zen" anahtari Turkce
            // "Metin Duzenleyici" girdisine takiliyordu. Sadece bastan
            // eslesme ve en az 3 harf kabul ediliyor.
            if (!byPrefix && key.length >= 3 && (id.startsWith(key) || nm.startsWith(key)))
                byPrefix = a;
        }

        return byLastSegment || byExec || byPrefix;
    }

    function iconFromName(name) {
        if (!name || name === "") return "";
        let p = Quickshell.iconPath(name, true);
        if (p && p !== "") return p;
        p = Quickshell.iconPath(normKey(name), true);
        if (p && p !== "") return p;
        return "";
    }

    function iconFromDesktop(name) {
        let entry = window.findEntry(name);
        if (!entry || !entry.icon || entry.icon === "") return "";
        return iconFromName(entry.icon);
    }

    // Sira: akisin kendi bildirdigi icon-name, sonra .desktop girdisi
    // uzerinden tema simgesi, en son ciplak isim/binary ile dogrudan arama.
    // Hicbiri tutmazsa "" doner ve Fader yazi tipi simgesine duser.
    function resolveIcon(node) {
        // Sadece bagimlilik kurmak icin okunuyor; deger kullanilmiyor.
        let _ = window.desktopEntryCount;

        let direct = iconFromName(propOf(node, "application.icon-name"));
        if (direct !== "") return direct;
        direct = iconFromName(propOf(node, "application.icon_name"));
        if (direct !== "") return direct;

        let names = [
            propOf(node, "application.name"),
            propOf(node, "application.process.binary"),
            node && node.nickname ? node.nickname : ""
        ];

        for (let i = 0; i < names.length; i++) {
            let d = iconFromDesktop(names[i]);
            if (d !== "") return d;
        }
        for (let i = 0; i < names.length; i++) {
            let d = iconFromName(names[i]);
            if (d !== "") return d;
        }
        return "";
    }

    function sinkLabel() {
        if (!window.sinkNode) return "Çıkış yok";
        let d = propOf(window.sinkNode, "device.profile.description");
        if (d === "") d = window.sinkNode.nickname || "";
        if (d === "") d = window.sinkNode.description || "";
        if (d === "") d = window.sinkNode.name || "";
        return d;
    }

    // =========================================================
    // KLAVYE SEÇİMİ
    // =========================================================
    property int selectedIndex: 0
    readonly property int faderCount: 1 + streamNodes.length

    onFaderCountChanged: {
        if (selectedIndex >= faderCount) selectedIndex = faderCount - 1;
        if (selectedIndex < 0) selectedIndex = 0;
    }

    function selectedFader() {
        if (selectedIndex === 0) return masterFader;
        let idx = selectedIndex - 1;
        if (idx < streamRow.count) return streamRow.itemAtIndex(idx);
        return null;
    }

    function adjustSelected(delta) {
        let f = selectedFader();
        if (f) f.nudge(delta);
    }

    Keys.onPressed: (event) => {
        switch (event.key) {
        case Qt.Key_Left:
            window.selectedIndex = Math.max(0, window.selectedIndex - 1);
            event.accepted = true; break;
        case Qt.Key_Right:
            window.selectedIndex = Math.min(window.faderCount - 1, window.selectedIndex + 1);
            event.accepted = true; break;
        case Qt.Key_Up:
            window.adjustSelected(event.modifiers & Qt.ShiftModifier ? 0.01 : 0.05);
            event.accepted = true; break;
        case Qt.Key_Down:
            window.adjustSelected(event.modifiers & Qt.ShiftModifier ? -0.01 : -0.05);
            event.accepted = true; break;
        case Qt.Key_M:
        case Qt.Key_Space:
            let f = window.selectedFader();
            if (f) f.toggleMute();
            event.accepted = true; break;
        case Qt.Key_0:
            let z = window.selectedFader();
            if (z) z.setVolume(0);
            event.accepted = true; break;
        case Qt.Key_1:
            let o = window.selectedFader();
            if (o) o.setVolume(1.0);
            event.accepted = true; break;
        }
    }

    // Açılış animasyonu — diğer popup'larla aynı his.
    property real introPhase: 0.0
    NumberAnimation on introPhase {
        running: true
        from: 0.0; to: 1.0
        duration: 200
        easing.type: Easing.OutCubic
    }

    // =========================================================
    // GÖVDE
    // =========================================================
    Rectangle {
        id: mainBg
        width: window.panelWidth
        height: window.layoutHeight

        // Uygulama acilip kapandikca panel yumusakca genisliyor/daraliyor.
        Behavior on width {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top

        radius: window.s(18)
        color: Qt.rgba(_theme.base.r, _theme.base.g, _theme.base.b, 1.0)
        border.color: _theme.surface1
        border.width: 1
        clip: true

        transform: Translate { y: (window.introPhase - 1) * window.s(30) }
        opacity: window.introPhase

        // ---------------- BAŞLIK ----------------
        Item {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: window.s(56)

            Text {
                id: title
                anchors.left: parent.left
                anchors.leftMargin: window.s(20)
                anchors.top: parent.top
                anchors.topMargin: window.s(12)
                text: "Ses Karıştırıcı"
                color: _theme.text
                font.pixelSize: window.s(16)
                font.bold: true
                font.family: "Inter, sans-serif"
            }

            Text {
                anchors.left: title.left
                anchors.top: title.bottom
                anchors.topMargin: window.s(1)
                text: window.sinkLabel()
                color: _theme.overlay1
                font.pixelSize: window.s(11)
                font.family: "Inter, sans-serif"
                elide: Text.ElideRight
                width: mainBg.width * 0.5
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: window.s(18)
                anchors.verticalCenter: parent.verticalCenter
                spacing: window.s(10)

                Repeater {
                    model: [
                        { k: "←→", l: "seç" },
                        { k: "↑↓", l: "seviye" },
                        { k: "M",  l: "sessiz" },
                        { k: "Esc", l: "kapat" }
                    ]

                    delegate: Row {
                        spacing: window.s(5)

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: hintKey.implicitWidth + window.s(10)
                            height: window.s(19)
                            radius: window.s(6)
                            color: Qt.rgba(_theme.surface0.r, _theme.surface0.g, _theme.surface0.b, 0.9)

                            Text {
                                id: hintKey
                                anchors.centerIn: parent
                                text: modelData.k
                                color: _theme.subtext0
                                font.pixelSize: window.s(10)
                                font.family: "Inter, sans-serif"
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.l
                            color: _theme.overlay1
                            font.pixelSize: window.s(10)
                            font.family: "Inter, sans-serif"
                        }
                    }
                }
            }
        }

        Rectangle {
            id: headerLine
            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Qt.rgba(_theme.surface1.r, _theme.surface1.g, _theme.surface1.b, 0.6)
        }

        // ---------------- SÜRGÜLER ----------------
        Item {
            id: content
            anchors.top: headerLine.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: window.edgePad

            property real faderWidth: window.stripWidth

            // Ana çıkış her zaman solda ve sabit: uygulama listesi değişse de
            // "genel ses" tuşunun yeri kaymasın.
            Mixer.Fader {
                id: masterFader
                x: 0
                y: 0
                width: content.faderWidth
                height: content.height
                node: window.sinkNode
                theme: _theme
                sc: scaler.baseScale
                maxVolume: window.maxVolume
                isMaster: true
                label: "Ana çıkış"
                sublabel: window.sinkLabel()
                iconGlyph: "\uf028"
                accent: _theme.mauve
                selected: window.selectedIndex === 0
                meterEnabled: window.visible
                onClicked: window.selectedIndex = 0
            }

            Rectangle {
                id: divider
                x: content.faderWidth + window.dividerGap
                width: 1
                y: window.s(10)
                height: content.height - window.s(20)
                color: Qt.rgba(_theme.surface1.r, _theme.surface1.g, _theme.surface1.b, 0.6)
            }

            ListView {
                id: streamRow
                anchors.left: divider.right
                anchors.leftMargin: window.dividerGap
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom

                orientation: ListView.Horizontal
                spacing: window.stripGap
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: window.streamNodes

                delegate: Mixer.Fader {
                    required property var modelData
                    required property int index

                    width: content.faderWidth
                    height: streamRow.height
                    node: modelData
                    theme: _theme
                    sc: scaler.baseScale
                    maxVolume: window.maxVolume
                    label: window.streamName(modelData)
                    sublabel: window.streamDetail(modelData)
                    iconSource: window.resolveIcon(modelData)
                    iconGlyph: "\uf001"
                    accent: _theme.blue
                    selected: window.selectedIndex === index + 1
                    meterEnabled: window.visible
                    onClicked: window.selectedIndex = index + 1
                }

                ScrollBar.horizontal: ScrollBar {
                    policy: streamRow.contentWidth > streamRow.width
                        ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                }
            }

            // Boş durum
            Column {
                anchors.centerIn: streamRow
                visible: window.streamNodes.length === 0
                spacing: window.s(8)

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "\uf026"
                    font.family: "Font Awesome 6 Free Solid"
                    font.pixelSize: window.s(26)
                    color: _theme.surface2
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Şu an ses çalan uygulama yok"
                    color: _theme.overlay1
                    font.pixelSize: window.s(12)
                    font.family: "Inter, sans-serif"
                }
            }
        }
    }
}
