pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../parts"
import "../../../core"

// Güç & pil: batarya sağlığı, güç profili ve boşta kalma davranışı.
//
// Kilit/uyku süreleri hypridle.conf'taki listener'lara yazılıyor — bu dosya
// kullanıcının kendi yapılandırması olduğu için ilk yazımda bir kez yedek
// alınıyor (system/power.sh).
ColumnLayout {
    id: page

    property var theme
    property real sf: 1.0

    readonly property bool hasSave: false
    readonly property bool dirty: false
    function save() {}

    function s(v) { return Math.round(v * page.sf); }
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }

    readonly property bool islandLaptop: Config.deviceKind === "laptop"
    readonly property bool islandDesktop: Config.deviceKind === "desktop"
    readonly property bool islandProfileUnset: Config.deviceKind === "unset"
    property bool islandPowerAdvancedOpen: false
    readonly property var islandDeviceOptions: [
        { value: "unset", label: "Henüz seçilmedi", detail: "Pil önerileri siz seçim yapana kadar çalışmaz" },
        { value: "laptop", label: "Laptop", detail: "Şarjdan çıkınca pil tasarrufu önerilebilir" },
        { value: "desktop", label: "Masaüstü bilgisayar", detail: "Pil önerileri normal görünümden gizlenir" }
    ]
    readonly property var islandSaverAnimOptions: [
        { value: "tint", label: "Renk yıkaması", detail: "Ada dolgusu ve kenarlığı amber tona geçer" },
        { value: "label", label: "Daralma & etiket", detail: "Ada kendi içinde \"Tasarruf\" yazısı açar" },
        { value: "sheen", label: "Kayan parıltı", detail: "Bir kez geçen ışık izi, arkasında amber ton bırakır" }
    ]

    function setIslandSaverAnim(value) {
        if (Config.powerSaverAnimStyles.indexOf(value) < 0) return;
        Config.powerSaverAnimStyle = value;
        page.saveIslandPower();
    }

    function saveIslandPower() {
        Config.saveDynamicIslandPowerSettings();
    }

    function setIslandDeviceKind(value) {
        if (Config.deviceKinds.indexOf(value) < 0) return;
        Config.deviceKind = value;
        if (value !== "laptop") Config.powerSaverMode = "normal";
        if (value === "desktop") page.islandPowerAdvancedOpen = false;
        page.saveIslandPower();
    }

    function resetIslandPower() {
        Config.deviceKind = "unset";
        Config.powerPromptEnabled = true;
        Config.powerSaverMode = "normal";
        page.saveIslandPower();
    }

    function islandProfileStatus() {
        if (page.islandLaptop) return "Laptop profili etkin";
        if (page.islandDesktop) return "Masaüstü profili etkin";
        return "Seçim bekleniyor";
    }

    function islandPowerSaverStatus() {
        if (Config.powerSaverMode === "battery-saver") return "Pil tasarrufu etkin";
        return "Normal";
    }

    readonly property string script: Qt.resolvedUrl("../system/power.sh").toString().replace(/^file:\/\//, "")

    property var st: ({
        battery: { present: false, capacity: 0, state: "", health: 0, timeText: "" },
        profile: "", profiles: [],
        idle: { running: false, lock: 0, suspend: 0 }
    })

    Process {
        id: statusProc
        stdout: StdioCollector {
            onStreamFinished: {
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

    Timer {
        interval: 10000
        repeat: true
        running: page.visible
        triggeredOnStart: true
        onTriggered: page.refresh()
    }

    // --- profil bilgileri ---
    function profileIcon(p) {
        if (p === "power-saver") return "󰌪";
        if (p === "balanced") return "󰓅";
        if (p === "performance") return "󱐋";
        return "󰾆";
    }
    function profileName(p) {
        if (p === "power-saver") return "Güç tasarrufu";
        if (p === "balanced") return "Dengeli";
        if (p === "performance") return "Performans";
        return p;
    }
    function profileHint(p) {
        if (p === "power-saver") return "En uzun pil ömrü, düşük işlemci hızı";
        if (p === "balanced") return "Günlük kullanım için varsayılan denge";
        if (p === "performance") return "En yüksek hız, en yüksek güç tüketimi";
        return "";
    }

    // --- pil ---
    readonly property bool charging: page.st.battery.state === "Charging"
    readonly property bool lowBattery: page.st.battery.present && page.st.battery.capacity <= 20
    readonly property color batteryTone: {
        if (page.charging) return page.theme.green;
        if (page.st.battery.capacity <= 15) return page.theme.red;
        if (page.st.battery.capacity <= 30) return page.theme.peach;
        return page.theme.green;
    }
    function batteryStateText(s) {
        if (s === "Charging") return "Şarj oluyor";
        if (s === "Discharging") return "Pilden çalışıyor";
        if (s === "Full") return "Tam dolu";
        if (s === "Not charging") return "Şarj etmiyor";
        return s;
    }
    function healthText(h) {
        if (h <= 0) return "bilinmiyor";
        if (h >= 90) return "%" + h + " · çok iyi";
        if (h >= 75) return "%" + h + " · iyi";
        if (h >= 60) return "%" + h + " · yıpranmış";
        return "%" + h + " · değiştirilmeli";
    }

    // --- boşta kalma süreleri ---
    function durationLabel(sec) {
        if (sec <= 0) return "Kapalı";
        if (sec < 3600) return (sec / 60) + " dakika";
        const h = Math.floor(sec / 3600);
        const m = Math.round((sec % 3600) / 60);
        return m === 0 ? h + " saat" : h + " saat " + m + " dakika";
    }

    // Seçenekler sabit bir liste DEĞİL: hypridle.conf elle düzenlenmiş olabilir
    // ve oradaki değer listede yoksa kutu "Seçilmedi" gösterip kullanıcının
    // gerçek ayarını görünmez yapıyordu. Dosyadaki değerler her zaman listeye
    // katılıyor, böylece kutu daima mevcut durumu gösteriyor.
    readonly property var idleOptions: {
        let secs = [0, 60, 180, 300, 600, 900, 1200, 1800, 2700, 3600];
        const current = [page.st.idle.lock, page.st.idle.suspend];
        for (let i = 0; i < current.length; i++) {
            const v = current[i];
            if (v > 0 && secs.indexOf(v) < 0) secs.push(v);
        }
        secs.sort(function(a, b) { return a - b; });
        let out = [];
        for (let i = 0; i < secs.length; i++)
            out.push({ value: String(secs[i]), label: page.durationLabel(secs[i]) });
        return out;
    }

    spacing: s(18)

    // ---------------------------------------------------------------
    // Pil
    // ---------------------------------------------------------------
    SettingCard {
        theme: page.theme
        sf: page.sf
        title: "PİL"
        visible: page.st.battery.present

        // Doluluk çubuğu: sayıyı okumadan önce durumu görmek için.
        //
        // Pil, sayfadaki tek gerçekten CANLI şey — sürekli değişiyor ve
        // kullanıcı buraya "ne durumdayım" diye bakıyor. O yüzden hareketin
        // tamamı duruma bağlı: şarjdayken çubukta akan bir parıltı, düşük
        // pilde nabız, yüzde değişince sayının kendi geçişi.
        Item {
            id: batteryHero
            Layout.fillWidth: true
            implicitHeight: page.s(76)

            // Ekranda gösterilen yüzde, gerçek değere doğru "sayarak" gider.
            // Anlık sıçrama bir okuma hatası gibi görünüyordu; kayan sayı
            // değerin gerçekten değiştiğini anlatıyor.
            property real shownCapacity: 0
            Behavior on shownCapacity {
                NumberAnimation { duration: 900; easing.type: Easing.OutCubic }
            }
            Connections {
                target: page
                function onStChanged() { batteryHero.shownCapacity = page.st.battery.capacity; }
            }
            Component.onCompleted: batteryHero.shownCapacity = page.st.battery.capacity

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: page.s(14)
                anchors.rightMargin: page.s(14)
                anchors.topMargin: page.s(10)
                anchors.bottomMargin: page.s(10)
                spacing: page.s(9)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: page.s(11)

                    Item {
                        Layout.preferredWidth: page.s(26)
                        Layout.preferredHeight: page.s(26)

                        Text {
                            id: batteryGlyph
                            anchors.centerIn: parent
                            text: page.charging ? "󰂄" : "󰁹"
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: page.s(21)
                            color: page.batteryTone
                            Behavior on color { ColorAnimation { duration: 300 } }

                            // Şarjdayken yavaş bir nefes; düşük pilde daha
                            // hızlı ve daha belirgin bir nabız.
                            SequentialAnimation on scale {
                                running: page.visible && (page.charging || page.lowBattery)
                                loops: Animation.Infinite
                                alwaysRunToEnd: true
                                NumberAnimation {
                                    to: page.lowBattery ? 1.18 : 1.08
                                    duration: page.lowBattery ? 520 : 1300
                                    easing.type: Easing.InOutSine
                                }
                                NumberAnimation {
                                    to: 1.0
                                    duration: page.lowBattery ? 520 : 1300
                                    easing.type: Easing.InOutSine
                                }
                            }
                        }

                        // Şarj başladığı an dışa açılan halka: fişi taktığın
                        // anda sistemin bunu gördüğü belli olsun.
                        Rectangle {
                            id: chargePing
                            anchors.centerIn: parent
                            width: page.s(26); height: page.s(26)
                            radius: width / 2
                            color: "transparent"
                            border.width: Math.max(1, page.s(2))
                            border.color: page.theme.green
                            opacity: 0
                            ParallelAnimation {
                                id: chargePingAnim
                                NumberAnimation { target: chargePing; property: "scale";   from: 0.8; to: 1.9; duration: 620; easing.type: Easing.OutCubic }
                                NumberAnimation { target: chargePing; property: "opacity"; from: 0.9; to: 0.0; duration: 620; easing.type: Easing.OutCubic }
                            }
                        }
                        Connections {
                            target: page
                            function onChargingChanged() { if (page.charging) chargePingAnim.restart(); }
                        }
                    }

                    Text {
                        text: "%" + Math.round(batteryHero.shownCapacity)
                        color: page.theme.text
                        font.family: "JetBrains Mono"
                        font.weight: Font.Bold
                        font.pixelSize: page.s(20)
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            Layout.fillWidth: true
                            text: page.batteryStateText(page.st.battery.state)
                            color: page.theme.subtext0
                            font.family: "JetBrains Mono"
                            font.pixelSize: page.s(11)
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: page.st.battery.timeText !== ""
                            text: (page.charging ? "dolmasına " : "bitmesine ") + page.st.battery.timeText
                            color: page.theme.overlay0
                            font.family: "JetBrains Mono"
                            font.pixelSize: page.s(9)
                            elide: Text.ElideRight
                        }
                    }
                }

                // --- doluluk çubuğu ---
                Rectangle {
                    id: batteryTrack
                    Layout.fillWidth: true
                    Layout.preferredHeight: page.s(9)
                    radius: height / 2
                    color: page.alpha(page.theme.surface2, 0.7)
                    clip: true

                    Rectangle {
                        id: batteryFill
                        width: parent.width * Math.max(0, Math.min(100, batteryHero.shownCapacity)) / 100
                        height: parent.height
                        radius: parent.radius

                        // Düz renk yerine kendi tonunun iki ucu: çubuk dolarken
                        // yüzey bir yöne akıyormuş gibi okunuyor.
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: page.alpha(page.batteryTone, 0.75) }
                            GradientStop { position: 1.0; color: page.batteryTone }
                        }
                        Behavior on width { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }

                        // Şarj akışı: dolu kısmın üzerinde soldan sağa kayan
                        // bir parıltı. Yalnızca fiş takılıyken çalışıyor —
                        // sürekli dönen bir efekt olsaydı anlamı kalmazdı.
                        Rectangle {
                            id: shimmer
                            height: parent.height
                            width: page.s(58)
                            visible: page.charging && batteryFill.width > width * 0.5
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.38) }
                                GradientStop { position: 1.0; color: "transparent" }
                            }
                            NumberAnimation on x {
                                running: shimmer.visible && page.visible
                                loops: Animation.Infinite
                                from: -shimmer.width
                                to: batteryTrack.width
                                duration: 1900
                            }
                        }
                    }

                    // Düşük pil uyarısı: çubuğun tamamı sönüp yanıyor.
                    SequentialAnimation on opacity {
                        running: page.visible && page.lowBattery && !page.charging
                        loops: Animation.Infinite
                        alwaysRunToEnd: true
                        NumberAnimation { to: 0.45; duration: 620; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0;  duration: 620; easing.type: Easing.InOutSine }
                    }
                }
            }
        }

        RowInfo {
            theme: page.theme; sf: page.sf
            label: "Pil sağlığı"
            value: page.healthText(page.st.battery.health)
            tone: page.st.battery.health > 0 && page.st.battery.health < 60
                  ? page.theme.peach : page.theme.subtext1
        }
    }

    // ---------------------------------------------------------------
    // Dynamic Island güç ve veri bütçesi
    // ---------------------------------------------------------------
    SettingCard {
        visible: !page.islandDesktop || page.islandPowerAdvancedOpen
        theme: page.theme
        sf: page.sf
        title: "DYNAMIC ISLAND · GÜÇ VE VERİ"

        Text {
            Layout.fillWidth: true
            Layout.leftMargin: page.s(14)
            Layout.rightMargin: page.s(14)
            text: "Dynamic Island'ın pil davranışını bilgisayar türünüze göre ayarlayın. Seçiminiz otomatik donanım tahmininden önceliklidir."
            color: page.theme.overlay0
            font.family: "JetBrains Mono"
            font.pixelSize: page.s(10)
            wrapMode: Text.WordWrap
            lineHeight: 1.25
        }

        RowAction {
            visible: page.islandDesktop
            theme: page.theme; sf: page.sf
            label: "Gelişmiş güç ayarları açık"
            hint: "Masaüstü profilinde yalnız teşhis ve profil değiştirme için görünür"
            buttonText: "GİZLE"
            buttonIcon: "󰅖"
            onTriggered: page.islandPowerAdvancedOpen = false
        }

        RowSelect {
            theme: page.theme; sf: page.sf
            label: "Bilgisayar türü"
            hint: "Bu seçim Dynamic Island'ın pil önerilerini yönlendirir"
            options: page.islandDeviceOptions
            currentValue: Config.deviceKind
            onPicked: (value) => page.setIslandDeviceKind(value)
        }

        RowToggle {
            visible: page.islandLaptop
            theme: page.theme; sf: page.sf
            label: "Pil önerisini göster"
            hint: "Şarj cihazı çıkarıldığında pil tasarrufu önerisi göster"
            checked: Config.powerPromptEnabled
            onToggled: (value) => {
                Config.powerPromptEnabled = value;
                page.saveIslandPower();
            }
        }

        RowInfo {
            visible: page.islandLaptop
            theme: page.theme; sf: page.sf
            label: "Pil tasarrufu modu"
            value: page.islandPowerSaverStatus()
            tone: Config.powerSaverMode === "battery-saver" ? page.theme.peach : page.theme.subtext1
        }

        RowSelect {
            visible: page.islandLaptop
            theme: page.theme; sf: page.sf
            label: "Etkinleşme animasyonu"
            hint: "Pil tasarrufu açılınca adanın kendisi ~4.5sn bunu gösterip eski haline döner"
            options: page.islandSaverAnimOptions
            currentValue: Config.powerSaverAnimStyle
            onPicked: (value) => page.setIslandSaverAnim(value)
        }

        RowInfo {
            visible: page.islandLaptop
            theme: page.theme; sf: page.sf
            label: "Şarja bağlanınca"
            value: "Öneri ayarları geri alınır"
            tone: page.theme.subtext1
        }

        Text {
            visible: page.islandLaptop
            Layout.fillWidth: true
            Layout.leftMargin: page.s(14)
            Layout.rightMargin: page.s(14)
            text: "Yalnızca pil önerisinin uyguladığı ayarlar geri alınır; elle seçtiğiniz ayarlar korunur."
            color: page.theme.overlay0
            font.family: "JetBrains Mono"
            font.pixelSize: page.s(10)
            wrapMode: Text.WordWrap
            lineHeight: 1.25
        }

        RowInfo {
            theme: page.theme; sf: page.sf
            label: "Profil durumu"
            value: page.islandProfileStatus()
            tone: page.islandProfileUnset ? page.theme.overlay0 : page.theme.green
        }

        RowAction {
            theme: page.theme; sf: page.sf
            label: "Güç ayarlarını sıfırla"
            hint: "Cihaz türünü ve pil önerisi tercihini varsayılana döndür"
            buttonText: "SIFIRLA"
            buttonIcon: "󰑐"
            onTriggered: page.resetIslandPower()
        }
    }

    SettingCard {
        visible: page.islandDesktop && !page.islandPowerAdvancedOpen
        theme: page.theme
        sf: page.sf
        title: "DYNAMIC ISLAND · GELİŞMİŞ"

        RowAction {
            theme: page.theme; sf: page.sf
            label: "Güç ve pil ayarları gizli"
            hint: "Masaüstü profilinde pil önerileri normal görünümde gösterilmez"
            buttonText: "GELİŞMİŞİ AÇ"
            buttonIcon: "󰅂"
            onTriggered: page.islandPowerAdvancedOpen = true
        }
    }

    // ---------------------------------------------------------------
    // Güç profili
    // ---------------------------------------------------------------
    SettingCard {
        theme: page.theme
        sf: page.sf
        title: "GÜÇ PROFİLİ"
        visible: page.st.profiles.length > 0

        Repeater {
            model: page.st.profiles

            delegate: RowDevice {
                required property var modelData

                theme: page.theme; sf: page.sf
                icon: page.profileIcon(modelData)
                name: page.profileName(modelData)
                detail: page.profileHint(modelData)
                connected: page.st.profile === modelData
                status: page.st.profile === modelData ? "etkin" : ""
                statusTone: page.theme.green
                expanded: false
                onClicked: if (page.st.profile !== modelData) page.run("profile", modelData)
            }
        }
    }

    // ---------------------------------------------------------------
    // Boşta kalma
    // ---------------------------------------------------------------
    SettingCard {
        theme: page.theme
        sf: page.sf
        title: "BOŞTA KALMA"

        RowToggle {
            theme: page.theme; sf: page.sf
            label: "Otomatik kilit ve uyku"
            hint: page.st.idle.running ? "hypridle çalışıyor" : "hypridle durduruldu — hiçbir zamanlayıcı işlemez"
            checked: page.st.idle.running
            onToggled: page.run("hypridle-toggle")
        }

        RowSelect {
            theme: page.theme; sf: page.sf
            label: "Ekranı kilitle"
            hint: "Bu süre boyunca hareket olmazsa oturum kilitlenir"
            options: page.idleOptions
            currentValue: String(page.st.idle.lock)
            onPicked: (v) => page.run("set-lock", v)
        }

        RowSelect {
            theme: page.theme; sf: page.sf
            label: "Uykuya al"
            hint: "Bu süre sonunda sistem askıya alınır"
            options: page.idleOptions
            currentValue: String(page.st.idle.suspend)
            onPicked: (v) => page.run("set-suspend", v)
        }
    }
}
