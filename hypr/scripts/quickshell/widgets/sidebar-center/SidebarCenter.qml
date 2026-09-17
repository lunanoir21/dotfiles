import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "../../core"

// Sağ kenar birleşik sidebar: pil/uptime başlığı, parlaklık/ses/mikrofon,
// hızlı geçişler, güç profili seçici, bildirim geçmişi ve mini takvim.
// Tamamen native — sadece sidebar_center_state.sh / sidebar_center_action.sh
// ile konuşur, hiçbir vendored (end-4) bileşene bağımlı değil.
Item {
    id: root

    property var notifModel: null
    property var liveNotifs: ({})
    property real layoutWidth: width
    property real layoutHeight: height

    // Bildirimin kendi ikonu (mutlak yol, file:// veya freedesktop icon adı)
    // öncelikli; yoksa gönderen uygulamanın masaüstü girdisinden düşülür.
    function resolveAppIcon(app, hint) {
        try {
            if (hint) {
                let value = String(hint);
                if (value.indexOf("file://") === 0) return value;
                if (value.indexOf("/") === 0) return "file://" + value;
                let named = Quickshell.iconPath(value, true);
                if (named) return named;
            }
            if (!app) return "";
            let entry = DesktopEntries.heuristicLookup(String(app));
            if (entry && entry.icon) {
                let path = Quickshell.iconPath(entry.icon, true);
                if (path) return path;
            }
            let direct = Quickshell.iconPath(String(app).toLowerCase(), true);
            if (direct) return direct;
        } catch (e) { console.warn("SidebarCenter icon lookup:", e); }
        return "";
    }

    Caching { id: paths }
    MatugenColors { id: theme }

    // Scaler *ekran* çözünürlüğü bekler, panelin kendi boyutunu değil — 1920x1080'i
    // 1.0 ölçeğe eşler. Buraya 440px'lik panel genişliği verilince
    // min(440/1920, …) 0.35 tabanına oturuyor ve tüm sidebar ~0.39x çizilip
    // üst köşeye büzülüyordu. Diğer tüm popup'lardaki konvansiyon ile aynı.
    Scaler { id: scaler; currentWidth: Screen.width; currentHeight: Screen.height }
    function s(val) { return scaler.s(val); }

    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }

    // ---- Hareket sabitleri -------------------------------------------------
    // Tek yerden yönetilen süreler; her animasyon bunları kullanıyor ki panel
    // baştan sona aynı ritimde hissedilsin.
    readonly property int tSnap: 130   // basma/bırakma gibi anlık geri bildirim
    readonly property int tBase: 240   // renk / opaklık geçişleri
    readonly property int tGlide: 340  // konum / boyut değişimleri
    readonly property int stagger: 42  // açılışta bölümler arası gecikme

    readonly property string dndDir: paths.getCacheDir("dnd")
    readonly property string scDir: paths.getCacheDir("sidebarcenter")
    readonly property string stateScript: Qt.resolvedUrl("sidebar_center_state.sh").toString().replace(/^file:\/\//, "")
    readonly property string actionScript: Qt.resolvedUrl("sidebar_center_action.sh").toString().replace(/^file:\/\//, "")
    readonly property string quickActionStatePath: root.scDir + "/quick-actions.json"

    // The profile selector stays fixed because it is a larger control with
    // its own menu. Everything in this catalog can be placed in the compact
    // quick-action row from the pencil editor.
    readonly property var defaultQuickActionIds: ["inhibit", "dnd", "night", "batterySaver"]
    readonly property var quickActionCatalog: [
        { id: "inhibit",      key: "inhibit",      action: "inhibit-toggle",       icon: "󰛊", label: "Awake",       hint: "Ekranı uyanık tut", tone: "yellow" },
        { id: "dnd",          key: "dnd",          action: "dnd-toggle",           icon: "󰂛", label: "DND",          hint: "Rahatsız etmeyin", tone: "red" },
        { id: "night",        key: "night",        action: "night-toggle",         icon: "󰽙", label: "Night",        hint: "Gece ışığını değiştir", tone: "peach" },
        { id: "batterySaver", key: "batterySaver", action: "battery-saver-toggle", icon: "󰁹", label: "Battery Saver", hint: "Pil tasarrufu paketini değiştir", tone: "green" },
        { id: "wifi",         key: "wifiOn",       action: "wifi-toggle",          icon: "󰤨", label: "Wi-Fi",        hint: "Wi-Fi radyosunu değiştir", tone: "blue" },
        { id: "bt",           key: "btOn",         action: "bt-toggle",            icon: "󰂯", label: "Bluetooth",    hint: "Bluetooth radyosunu değiştir", tone: "sapphire" },
        { id: "eq",           key: "easyeffects",  action: "easyeffects-toggle",   icon: "󰗀", label: "EasyEffects",   hint: "Ses efektlerini değiştir", tone: "mauve" },
        { id: "volumeMute",   key: "volMuted",     action: "volume-mute",          icon: "󰕾", label: "Mute",         hint: "Sesi aç/kapat", tone: "teal" },
        { id: "micMute",      key: "micMuted",     action: "mic-mute",             icon: "󰍬", label: "Mic",          hint: "Mikrofonu aç/kapat", tone: "lavender" }
    ]
    property var quickActionIds: root.defaultQuickActionIds.slice()
    property bool quickActionStateLoaded: false

    FileView {
        id: quickActionStore
        path: root.quickActionStatePath
        preload: true
        watchChanges: false
        onLoaded: root.loadQuickActionState()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                root.quickActionStateLoaded = true;
                quickActionAdapter.ids = root.quickActionIds;
                quickActionWriteTimer.restart();
            }
        }
        onAdapterUpdated: {
            if (root.quickActionStateLoaded) quickActionWriteTimer.restart();
        }
        adapter: JsonAdapter {
            id: quickActionAdapter
            property list<string> ids: []
        }
    }

    Timer {
        id: quickActionWriteTimer
        interval: 140
        repeat: false
        onTriggered: quickActionStore.writeAdapter()
    }

    function quickActionDefinition(id) {
        for (let i = 0; i < root.quickActionCatalog.length; i++) {
            if (root.quickActionCatalog[i].id === id) return root.quickActionCatalog[i];
        }
        return null;
    }

    function normalizedQuickActionIds(ids) {
        let valid = [];
        if (!Array.isArray(ids)) return valid;
        for (let i = 0; i < ids.length; i++) {
            let id = String(ids[i]);
            if (root.quickActionDefinition(id) && valid.indexOf(id) === -1) valid.push(id);
        }
        return valid;
    }

    function loadQuickActionState() {
        let saved = normalizedQuickActionIds(quickActionAdapter.ids);
        root.quickActionIds = saved.length > 0 ? saved : root.defaultQuickActionIds.slice();
        root.quickActionStateLoaded = true;
        quickActionAdapter.ids = root.quickActionIds;
    }

    function setQuickActionIds(ids) {
        let next = normalizedQuickActionIds(ids);
        root.quickActionIds = next;
        if (root.quickActionStateLoaded) quickActionAdapter.ids = next;
    }

    function addQuickAction(id) {
        if (root.quickActionIds.indexOf(id) >= 0) return;
        let next = root.quickActionIds.slice();
        next.push(id);
        root.setQuickActionIds(next);
    }

    function removeQuickAction(id) {
        let next = root.quickActionIds.slice();
        let at = next.indexOf(id);
        if (at < 0) return;
        next.splice(at, 1);
        root.setQuickActionIds(next);
    }

    function moveQuickAction(id, direction) {
        let next = root.quickActionIds.slice();
        let at = next.indexOf(id);
        let target = at + direction;
        if (at < 0 || target < 0 || target >= next.length) return;
        let moved = next[at];
        next[at] = next[target];
        next[target] = moved;
        root.setQuickActionIds(next);
    }

    function quickActionAccent(item) {
        if (!item) return theme.overlay0;
        if (item.tone === "yellow") return theme.yellow;
        if (item.tone === "green") return theme.green;
        if (item.tone === "red") return theme.red;
        if (item.tone === "peach") return theme.peach;
        if (item.tone === "blue") return theme.blue;
        if (item.tone === "sapphire") return theme.sapphire;
        if (item.tone === "mauve") return theme.mauve;
        if (item.tone === "teal") return theme.teal;
        if (item.tone === "lavender") return theme.blue;
        return theme.overlay0;
    }

    function quickActionActive(item) {
        return item && root.sysState[item.key] === true;
    }

    function activateQuickAction(item) {
        if (!item) return;
        if (item.id === "wifi") return root.toggleWifiRadio();
        if (item.id === "bt") return root.toggleBtRadio();
        root.toggleWith(item.key, item.action);
    }

    function availableQuickActions() {
        let available = [];
        for (let i = 0; i < root.quickActionCatalog.length; i++) {
            let item = root.quickActionCatalog[i];
            if (root.quickActionIds.indexOf(item.id) < 0) available.push(item);
        }
        return available;
    }

    function envPrefix() {
        return "QS_CACHE_DND='" + root.dndDir + "' QS_CACHE_SIDEBARCENTER='" + root.scDir + "' ";
    }

    property var sysState: ({
        uptime: "", batPresent: false, batCapacity: 0, batCharging: false,
        volume: 0, volMuted: false, mic: 0, micMuted: false,
        brightness: 0, brightPresent: false,
        wifiOn: false, wifiSsid: "", wifiSignal: 0,
        btOn: false, btDevice: "",
        easyeffects: false, profile: "", profiles: [],
        inhibit: false, night: false, dnd: false, batterySaver: false
    })

    Process {
        id: stateProc
        command: ["bash", "-c", root.envPrefix() + "bash '" + root.stateScript + "'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.sysState = JSON.parse(this.text.trim());
                } catch (e) {}
            }
        }
    }

    function pollNow() {
        if (!stateProc.running) stateProc.running = true;
    }

    // Panel gizliyken de yavaş tempoda dönüyor: açıldığı anda ekranda taze veri
    // olsun diye. Script artık ~130ms (eskiden ~840ms) sürdüğü için 10sn'lik
    // arka plan tempo­sunun maliyeti ihmal edilebilir.
    Timer {
        id: pollTimer
        interval: root.visible ? 1500 : 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.pollNow()
    }

    Process {
        id: actionProc
        stdout: StdioCollector {}
    }

    // Bir eylemden sonra iki kez doğrula: ilki anında (yerel iyimser değeri
    // gerçekle karşılaştırmak için), ikincisi wifi/bluetooth gibi donanımın
    // oturması saniye sürebilen şeyler için.
    Timer { id: verifyQuick;  interval: 250;  onTriggered: root.pollNow() }
    Timer { id: verifySettle; interval: 1400; onTriggered: root.pollNow() }

    function runAction(action, value) {
        let cmd = root.envPrefix() + "bash '" + root.actionScript + "' " + action;
        if (value !== undefined && value !== null && value !== "") cmd += " '" + value + "'";
        actionProc.command = ["bash", "-c", cmd];
        actionProc.running = true;
        verifyQuick.restart();
        verifySettle.restart();
    }

    // Tıklamanın sonucunu beklemeden arayüzü güncelle. Script + poll gidiş
    // dönüşü en iyi ihtimalle ~150ms; iyimser güncelleme olmadan her toggle
    // "takılmış" gibi hissettiriyordu. Yanlış tahmin edersek bir sonraki poll
    // (250ms) zaten üzerine yazıyor.
    function patchState(key, val) {
        let next = {};
        for (let k in root.sysState) next[k] = root.sysState[k];
        next[key] = val;
        root.sysState = next;
    }

    function toggleWith(key, action) {
        root.patchState(key, !root.sysState[key]);
        root.runAction(action);
    }

    // ---- Wi-Fi ağ listesi --------------------------------------------------
    // Pill'e tıklamak artık radyoyu değil ağ listesini açıyor; radyo anahtarı
    // pill'in sağ üstündeki küçük güç simgesi. Liste wifi_list.sh'ten (nmcli)
    // geliyor, bağlan/kes/unut eylemleri sidebar_center_action.sh üzerinden.
    property bool wifiOpen: false
    property var wifiNets: []
    property bool wifiScanning: false
    property string wifiExpanded: ""   // satırı açık olan SSID
    property string wifiBusy: ""       // üzerinde işlem süren SSID
    property string wifiError: ""

    readonly property string wifiListScript: Qt.resolvedUrl("wifi_list.sh").toString().replace(/^file:\/\//, "")

    // UTF-8 güvenli base64. SSID ve parola tek tırnaklı bir kabuk komutuna
    // gömülüyor; içindeki tırnak, boşluk ya da Türkçe karakter komutu bozmasın
    // diye ikisini de kodlayıp karşı tarafta base64 -d ile açıyoruz.
    function b64(str) {
        const enc = encodeURIComponent(str);
        let out = "";
        for (let i = 0; i < enc.length; i++) {
            if (enc[i] === "%") {
                out += String.fromCharCode(parseInt(enc.substr(i + 1, 2), 16));
                i += 2;
            } else {
                out += enc[i];
            }
        }
        return Qt.btoa(out);
    }

    Process {
        id: wifiListProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.wifiScanning = false;
                try {
                    root.wifiNets = (JSON.parse(this.text.trim()).nets) || [];
                } catch (e) {
                    root.wifiNets = [];
                }
            }
        }
    }

    // rescan=true taze tarama yaptırır (birkaç saniye); panel ilk açılışta ve
    // yenile düğmesinde kullanılır, periyodik tazelemede cache'e güveniyoruz.
    function scanWifi(rescan) {
        if (wifiListProc.running) return;
        root.wifiScanning = true;
        wifiListProc.command = ["bash", "-c",
            "bash '" + root.wifiListScript + "'" + (rescan ? " rescan" : "")];
        wifiListProc.running = true;
    }

    // Panel kapalıyken nmcli'ye hiç dokunma.
    Timer {
        id: wifiPoll
        interval: 8000
        repeat: true
        running: root.visible && root.wifiOpen
        onTriggered: root.scanWifi(false)
    }

    Process {
        id: wifiActionProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.wifiBusy = "";
                try {
                    const r = JSON.parse(this.text.trim());
                    root.wifiError = r.ok ? "" : (r.msg || "İşlem başarısız");
                    if (r.ok) root.wifiExpanded = "";
                } catch (e) {
                    root.wifiError = "";
                }
                root.scanWifi(false);
                root.pollNow();
            }
        }
    }

    function wifiRun(action, ssid, password) {
        if (wifiActionProc.running) return;
        root.wifiError = "";
        root.wifiBusy = ssid;
        let cmd = root.envPrefix() + "bash '" + root.actionScript + "' " + action
                + " '" + root.b64(ssid) + "'";
        if (password !== undefined && password !== null && password !== "")
            cmd += " '" + root.b64(password) + "'";
        wifiActionProc.command = ["bash", "-c", cmd];
        wifiActionProc.running = true;
    }

    function wifiIcon(sig) {
        if (sig >= 75) return "󰤨";
        if (sig >= 55) return "󰤥";
        if (sig >= 35) return "󰤢";
        if (sig >= 15) return "󰤟";
        return "󰤯";
    }

    function wifiRowHint(net) {
        if (net.inUse) return "Bağlı" + (net.signal > 0 ? " · %" + net.signal : "");
        if (!net.visible) return "Kayıtlı · menzil dışı";
        let bits = ["%" + net.signal];
        if (net.saved) bits.push("kayıtlı");
        bits.push(net.secured ? "korumalı" : "açık");
        return bits.join(" · ");
    }

    function toggleWifiPanel() {
        root.wifiOpen = !root.wifiOpen;
        if (root.wifiOpen) {
            root.profileOpen = false;
            root.powerOpen = false;
            root.btOpen = false;
            root.wifiError = "";
            root.scanWifi(true);
        } else {
            root.wifiExpanded = "";
        }
    }

    // Radyo kapatılınca liste anlamsız: paneli de temizle.
    function toggleWifiRadio() {
        const turningOff = root.sysState.wifiOn;
        root.toggleWith("wifiOn", "wifi-toggle");
        if (turningOff) {
            root.wifiNets = [];
            root.wifiExpanded = "";
            root.wifiOpen = false;
        } else {
            root.wifiOpen = true;
            wifiAfterOn.restart();
        }
    }
    // Radyo açıldıktan sonra kart tarama yapana kadar biraz zaman geçiyor.
    Timer { id: wifiAfterOn; interval: 1200; onTriggered: root.scanWifi(true) }

    // ---- Bluetooth cihaz listesi -------------------------------------------
    // Wi-Fi ile aynı dil: pill'in gövdesi listeyi açar, sağ üstteki küçük güç
    // simgesi radyoyu açıp kapatır. Liste ve eylemler settings sayfasıyla aynı
    // script'ten geliyor (settings/system/bluetooth.sh) — tek doğru kaynak.
    property bool btOpen: false
    property var btDevices: []
    property bool btBusyList: false
    property string btExpanded: ""   // satırı açık olan MAC
    property string btBusy: ""       // üzerinde işlem süren MAC
    property string btError: ""
    property bool btDiscovering: false

    readonly property string btScript: Qt.resolvedUrl("../settings/system/bluetooth.sh").toString().replace(/^file:\/\//, "")

    Process {
        id: btListProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.btBusyList = false;
                try {
                    const st = JSON.parse(this.text.trim());
                    root.btDevices = st.devices || [];
                    root.btDiscovering = !!st.discovering;
                } catch (e) {
                    root.btDevices = [];
                    root.btDiscovering = false;
                }
            }
        }
    }

    function refreshBt() {
        if (btListProc.running) return;
        root.btBusyList = true;
        btListProc.command = ["bash", "-c", "bash '" + root.btScript + "' status"];
        btListProc.running = true;
    }

    // Panel kapalıyken bluetoothctl'e hiç dokunma. Tarama açıkken liste hızlı
    // değiştiği için tempo da hızlanıyor.
    Timer {
        id: btPoll
        interval: root.btDiscovering ? 2500 : 7000
        repeat: true
        running: root.visible && root.btOpen
        onTriggered: root.refreshBt()
    }

    Process {
        id: btActionProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.btBusy = "";
                try {
                    const r = JSON.parse(this.text.trim());
                    root.btError = r.ok ? "" : (r.msg || "İşlem tamamlanamadı");
                    if (r.ok) root.btExpanded = "";
                } catch (e) {
                    root.btError = "";
                }
                root.refreshBt();
                root.pollNow();
            }
        }
    }

    // Eşleştirme/bağlanma onlarca saniye sürebiliyor: butonu kilitlemek yerine
    // satırda "işleniyor…" gösterip cevabı bekliyoruz.
    function btRun(action, mac) {
        if (btActionProc.running) return;
        root.btError = "";
        root.btBusy = (mac === undefined ? "" : mac);
        let cmd = "bash '" + root.btScript + "' " + action;
        if (mac !== undefined && mac !== "") cmd += " '" + mac + "'";
        btActionProc.command = ["bash", "-c", cmd];
        btActionProc.running = true;
    }

    function btToggleScan() {
        root.btRun(root.btDiscovering ? "scan-off" : "scan-on");
    }

    // Cihaz türünü addan tahmin ediyoruz: bluetoothctl'in ikon alanını almak
    // cihaz başına ayrı bir sorgu demek, tahmin bedava ve çoğu zaman doğru.
    function btIcon(name) {
        const n = String(name).toLowerCase();
        if (/kulak|head|buds|airpod|wh-|wf-|earphone/.test(n)) return "󰋋";
        if (/speaker|hoparlör|soundbar|jbl|boom/.test(n)) return "󰓃";
        if (/mouse|fare/.test(n)) return "󰍽";
        if (/keyboard|klavye/.test(n)) return "󰌌";
        if (/phone|telefon|iphone|galaxy|pixel/.test(n)) return "󰄜";
        if (/watch|saat|band/.test(n)) return "󰖉";
        if (/tv|monitor/.test(n)) return "󰔂";
        return "󰂯";
    }

    function btRowHint(dev) {
        if (dev.connected) return "Bağlı";
        if (dev.paired) return "Eşleştirilmiş · kayıtlı";
        return "Eşleştirilmemiş";
    }

    function toggleBtPanel() {
        root.btOpen = !root.btOpen;
        if (root.btOpen) {
            root.wifiOpen = false;
            root.profileOpen = false;
            root.powerOpen = false;
            root.btError = "";
            root.refreshBt();
        } else {
            root.btExpanded = "";
            // Panel kapanınca tarama açık kalırsa pili boşuna yer.
            if (root.btDiscovering) root.btRun("scan-off");
        }
    }

    // Radyo kapatılınca liste anlamsız: paneli de temizle.
    function toggleBtRadio() {
        const turningOff = root.sysState.btOn;
        root.toggleWith("btOn", "bt-toggle");
        if (turningOff) {
            root.btDevices = [];
            root.btExpanded = "";
            root.btDiscovering = false;
            root.btOpen = false;
        } else {
            root.btOpen = true;
            btAfterOn.restart();
        }
    }
    // Adaptör açıldıktan sonra bluez'in oturması biraz zaman alıyor.
    Timer { id: btAfterOn; interval: 1200; onTriggered: root.refreshBt() }

    // ---- Güç profili -------------------------------------------------------
    property bool profileOpen: false

    function profileIcon(p) {
        if (p === "power-saver") return "󰌪";
        if (p === "balanced") return "󰓅";
        if (p === "performance") return "󱐋";
        return "󰾆";
    }
    function profileColor(p) {
        if (p === "power-saver") return theme.green;
        if (p === "balanced") return theme.blue;
        if (p === "performance") return theme.peach;
        return theme.overlay0;
    }
    function profileName(p) {
        if (p === "power-saver") return "Power Saver";
        if (p === "balanced") return "Balanced";
        if (p === "performance") return "Performance";
        return p === "" ? "—" : p;
    }
    function profileHint(p) {
        if (p === "power-saver") return "Uzun pil, düşük saat";
        if (p === "balanced") return "Varsayılan denge";
        if (p === "performance") return "Tam güç, sıcak ve hızlı";
        return "";
    }

    function setProfile(p) {
        if (p === root.sysState.profile) { root.profileOpen = false; return; }
        root.patchState("profile", p);
        root.runAction("profile", p);
        root.profileOpen = false;
    }

    // ---- Güç menüsü (kilit / uyku / kapat) ---------------------------------
    property bool powerOpen: false

    readonly property var powerOptions: [
        { action: "lock",     icon: "󰌾", name: "Kilitle",   hint: "Ekranı kilitle" },
        { action: "suspend",  icon: "󰒲", name: "Uykuya al", hint: "Askıya al, durumu koru" },
        { action: "poweroff", icon: "󰐥", name: "Kapat",     hint: "Sistemi tamamen kapat" }
    ]

    function powerColor(a) {
        if (a === "lock") return theme.blue;
        if (a === "suspend") return theme.mauve;
        if (a === "poweroff") return theme.red;
        return theme.overlay0;
    }

    function runPower(a) {
        root.powerOpen = false;
        root.runAction(a);
    }

    // ---- Açılış animasyonu -------------------------------------------------
    // Bölümler sırayla süzülerek gelir. `revealed` binding olarak değil
    // imperatif set ediliyor ki panel gizlenip tekrar açıldığında baştan oynasın.
    property bool revealed: false
    property bool editMode: false
    Timer { id: revealKick; interval: 16; onTriggered: root.revealed = true }

    onVisibleChanged: {
        if (visible) {
            root.pollNow();
            revealKick.restart();
        } else {
            root.revealed = false;
            root.profileOpen = false;
            root.powerOpen = false;
            root.editMode = false;
            root.wifiOpen = false;
            root.wifiExpanded = "";
            root.wifiError = "";
            // Tarama arka planda dönüyor olabilir: sidebar kapanırken durdur.
            if (root.btDiscovering) root.btRun("scan-off");
            root.btOpen = false;
            root.btExpanded = "";
            root.btError = "";
        }
    }

    Component.onCompleted: {
        updateCalendarGrid();
        if (root.visible) root.revealed = true;
    }

    // -------------------------------------------------------------------
    // Relative "Xm / Xh" formatting for notification timestamps
    // -------------------------------------------------------------------
    property real nowTick: Date.now()
    Timer { interval: 30000; running: root.visible; repeat: true; onTriggered: root.nowTick = Date.now() }
    function timeAgo(ts) {
        if (!ts) return "";
        let diff = Math.max(0, Math.floor((root.nowTick - ts) / 1000));
        if (diff < 60) return "now";
        if (diff < 3600) return Math.floor(diff / 60) + "m";
        if (diff < 86400) return Math.floor(diff / 3600) + "h";
        return Math.floor(diff / 86400) + "d";
    }

    // Modelden silmek tek başına yetmez: NotificationServer nesneyi canlı
    // tuttuğu için bir sonraki reload veya başka bir olayda geri yayınlayabilir.
    // Önce gerçek bildirimi kapat, ardından Sidebar Center listesinden çıkar.
    function dismissNotificationAt(index) {
        if (!root.notifModel || index < 0 || index >= root.notifModel.count) return;
        let entry = root.notifModel.get(index);
        let notification = entry ? entry.notif : null;
        if (notification) {
            try { notification.dismiss(); } catch (e) {}
        }
        if (entry && entry.uid !== undefined && root.liveNotifs) {
            delete root.liveNotifs[entry.uid];
        }
        root.notifModel.remove(index);
    }

    function clearNotifications() {
        if (!root.notifModel) return;
        for (let i = root.notifModel.count - 1; i >= 0; i--) {
            let entry = root.notifModel.get(i);
            let notification = entry ? entry.notif : null;
            if (notification) {
                try { notification.dismiss(); } catch (e) {}
            }
            if (entry && entry.uid !== undefined && root.liveNotifs) {
                delete root.liveNotifs[entry.uid];
            }
        }
        root.notifModel.clear();
    }

    // -------------------------------------------------------------------
    // Mini calendar grid
    // -------------------------------------------------------------------
    property int monthOffset: 0
    property int monthDir: 1
    property string monthLabel: ""
    ListModel { id: calendarModel }

    function updateCalendarGrid() {
        let d = new Date();
        d.setDate(1);
        d.setMonth(d.getMonth() + root.monthOffset);

        let targetMonth = d.getMonth();
        let targetYear = d.getFullYear();

        let today = new Date();
        let isCurMonth = (today.getMonth() === targetMonth && today.getFullYear() === targetYear);
        let todayDate = today.getDate();

        root.monthLabel = Qt.formatDateTime(d, "MMMM yyyy");

        let firstDay = new Date(targetYear, targetMonth, 1).getDay();
        firstDay = (firstDay === 0) ? 6 : firstDay - 1;

        let daysInMonth = new Date(targetYear, targetMonth + 1, 0).getDate();
        let daysInPrev = new Date(targetYear, targetMonth, 0).getDate();

        calendarModel.clear();
        for (let i = firstDay - 1; i >= 0; i--) {
            calendarModel.append({ dayNum: (daysInPrev - i).toString(), isCurrentMonth: false, isToday: false });
        }
        for (let i = 1; i <= daysInMonth; i++) {
            calendarModel.append({ dayNum: i.toString(), isCurrentMonth: true, isToday: (isCurMonth && i === todayDate) });
        }
        let remaining = 42 - calendarModel.count;
        for (let i = 1; i <= remaining; i++) {
            calendarModel.append({ dayNum: i.toString(), isCurrentMonth: false, isToday: false });
        }
    }

    function stepMonth(dir) {
        root.monthDir = dir;
        root.monthOffset += dir;
    }

    // Ay değişimi: önce eski ızgara kayarak solar, ScriptAction modeli
    // tazeler, sonra yenisi ters yönden kayarak girer. Model güncellemesi
    // animasyonun *içinde* olmalı, yoksa geçiş sırasında yeni günler eski
    // ızgarada bir kare görünüp titriyor.
    onMonthOffsetChanged: monthSwap.restart()

    SequentialAnimation {
        id: monthSwap
        ParallelAnimation {
            NumberAnimation { target: calBody; property: "opacity"; to: 0; duration: 110; easing.type: Easing.InCubic }
            NumberAnimation { target: calBodyShift; property: "x"; to: -root.monthDir * root.s(26); duration: 110; easing.type: Easing.InCubic }
        }
        ScriptAction {
            script: {
                root.updateCalendarGrid();
                calBodyShift.x = root.monthDir * root.s(26);
            }
        }
        ParallelAnimation {
            NumberAnimation { target: calBody; property: "opacity"; to: 1; duration: root.tBase; easing.type: Easing.OutCubic }
            NumberAnimation { target: calBodyShift; property: "x"; to: 0; duration: root.tGlide; easing.type: Easing.OutCubic }
        }
    }

    // =====================================================================
    // UI
    // =====================================================================
    Rectangle {
        id: shell
        anchors.fill: parent
        radius: s(24)
        color: theme.crust
        border.width: 1
        border.color: root.alpha(theme.text, 0.08)
        clip: true

        // Panelin kendisi de hafifçe büyüyerek gelir — StackView'ın kendi
        // 0.98 scale geçişinin üstüne binen ince bir derinlik katmanı.
        scale: root.revealed ? 1.0 : 0.985
        Behavior on scale { NumberAnimation { duration: root.tGlide; easing.type: Easing.OutCubic } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: s(18)
            spacing: s(14)

            // -----------------------------------------------------------
            // HEADER: battery / uptime + quick actions
            // -----------------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: s(8)

                opacity: root.revealed ? 1 : 0
                Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 0 * root.stagger } NumberAnimation { duration: root.tBase; easing.type: Easing.OutCubic } } }
                transform: Translate {
                    y: root.revealed ? 0 : root.s(20)
                    Behavior on y { SequentialAnimation { PauseAnimation { duration: 0 * root.stagger } NumberAnimation { duration: 460; easing.type: Easing.OutBack; easing.overshoot: 0.7 } } }
                }

                Text {
                    visible: root.sysState.batPresent
                    text: root.sysState.batCharging ? "󰂄" : (root.sysState.batCapacity > 20 ? "󰁹" : "󰂃")
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: s(16)
                    color: root.sysState.batCharging ? theme.green : (root.sysState.batCapacity < 20 ? theme.red : theme.text)
                    Behavior on color { ColorAnimation { duration: root.tBase } }

                    // Şarjdayken ikon nefes alsın — ekrana bakmadan da fark edilir.
                    SequentialAnimation on opacity {
                        running: root.sysState.batCharging && root.visible
                        loops: Animation.Infinite
                        alwaysRunToEnd: true
                        NumberAnimation { to: 0.45; duration: 900; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0;  duration: 900; easing.type: Easing.InOutSine }
                    }
                }

                Text {
                    visible: root.sysState.batPresent
                    text: root.sysState.batCapacity + "%"
                    color: theme.text
                    font.family: "JetBrains Mono"
                    font.weight: Font.DemiBold
                    font.pixelSize: s(13)
                }

                Text {
                    text: root.sysState.uptime !== "" ? "· ↑ " + root.sysState.uptime : ""
                    color: theme.subtext0
                    font.family: "JetBrains Mono"
                    font.pixelSize: s(12)
                }

                Item { Layout.fillWidth: true }

                Repeater {
                    model: [
                        { icon: "󰒓", action: "settings" },
                        { icon: "󰏫", action: "edit" },
                        { icon: "󰑐", action: "reload" },
                        { icon: "󰐥", action: "power" }
                    ]
                    delegate: Rectangle {
                        id: hdrBtn
                        property bool hovered: hdrMa.containsMouse
                        Layout.preferredWidth: s(30)
                        Layout.preferredHeight: s(30)
                        radius: s(15)
                        readonly property bool active: (modelData.action === "power" && root.powerOpen)
                                                   || (modelData.action === "edit" && root.editMode)
                        color: active ? root.alpha(modelData.action === "edit" ? theme.teal : theme.red, 0.20)
                                      : (hovered ? theme.surface1 : "transparent")
                        Behavior on color { ColorAnimation { duration: root.tBase } }

                        scale: hdrMa.pressed ? 0.86 : (hovered ? 1.08 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }

                        Text {
                            id: hdrIcon
                            anchors.centerIn: parent
                            text: modelData.icon
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: s(14)
                            color: hdrBtn.active ? (modelData.action === "edit" ? theme.teal : theme.red)
                                                 : (hdrBtn.hovered ? theme.text : theme.subtext0)
                            Behavior on color { ColorAnimation { duration: root.tBase } }

                            // Reload düğmesi tıklanınca ikon bir tur döner:
                            // reload sırasında süreç yeniden yükleneceği için
                            // başka hiçbir geri bildirim şansı yok.
                            RotationAnimation {
                                id: hdrSpin
                                target: hdrIcon
                                from: 0; to: 360
                                duration: 520
                                easing.type: Easing.OutCubic
                            }
                        }

                        MouseArea {
                            id: hdrMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.action === "settings") {
                                    Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle settings"]);
                                } else if (modelData.action === "reload") {
                                    hdrSpin.restart();
                                    Quickshell.reload(true);
                                } else if (modelData.action === "edit") {
                                    root.editMode = !root.editMode;
                                    if (root.editMode) {
                                        root.profileOpen = false;
                                        root.powerOpen = false;
                                    }
                                } else if (modelData.action === "power") {
                                    root.powerOpen = !root.powerOpen;
                                    if (root.powerOpen) root.profileOpen = false;
                                }
                            }
                        }
                    }
                }
            }

            // -----------------------------------------------------------
            // GÜÇ MENÜSÜ (başlıktaki güç düğmesinden açılır)
            // -----------------------------------------------------------
            Item {
                id: powerPanel
                Layout.fillWidth: true
                clip: true

                // profilePanel ile aynı numara: Layout.preferredHeight attached
                // property olduğu için animasyon ara bir property üzerinde.
                property real openH: root.powerOpen ? powerCol.implicitHeight : 0
                Behavior on openH { NumberAnimation { duration: root.tGlide; easing.type: Easing.OutCubic } }
                Layout.preferredHeight: openH
                visible: openH > 0.5

                opacity: root.powerOpen ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: root.tBase; easing.type: Easing.OutCubic } }

                ColumnLayout {
                    id: powerCol
                    width: parent.width
                    spacing: s(6)

                    Repeater {
                        model: root.powerOptions

                        delegate: Rectangle {
                            id: pwrOpt
                            readonly property color accent: root.powerColor(modelData.action)

                            Layout.fillWidth: true
                            Layout.preferredHeight: s(46)
                            radius: s(12)
                            color: pwrOptMa.containsMouse ? root.alpha(accent, 0.18)
                                                          : root.alpha(theme.surface0, 0.5)
                            border.width: 1
                            border.color: pwrOptMa.containsMouse ? accent : root.alpha(theme.text, 0.06)
                            Behavior on color { ColorAnimation { duration: root.tBase } }
                            Behavior on border.color { ColorAnimation { duration: root.tBase } }

                            scale: pwrOptMa.pressed ? 0.97 : 1.0
                            Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }

                            opacity: root.powerOpen ? 1 : 0
                            Behavior on opacity { SequentialAnimation { PauseAnimation { duration: index * 55 } NumberAnimation { duration: root.tBase; easing.type: Easing.OutCubic } } }
                            transform: Translate {
                                x: root.powerOpen ? 0 : root.s(-18)
                                Behavior on x { SequentialAnimation { PauseAnimation { duration: index * 55 } NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.1 } } }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: s(12)
                                anchors.rightMargin: s(12)
                                spacing: s(10)

                                Text {
                                    text: modelData.icon
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: s(17)
                                    color: pwrOptMa.containsMouse ? pwrOpt.accent : theme.subtext0
                                    Behavior on color { ColorAnimation { duration: root.tBase } }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.name
                                        color: pwrOptMa.containsMouse ? theme.text : theme.subtext0
                                        font.family: "JetBrains Mono"
                                        font.weight: Font.DemiBold
                                        font.pixelSize: s(11)
                                        elide: Text.ElideRight
                                        Behavior on color { ColorAnimation { duration: root.tBase } }
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.hint
                                        color: theme.overlay0
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: s(9)
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            MouseArea {
                                id: pwrOptMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.runPower(modelData.action)
                            }
                        }
                    }
                }
            }

            // -----------------------------------------------------------
            // BRIGHTNESS BAR
            // -----------------------------------------------------------
            Rectangle {
                id: brightTrack
                visible: root.sysState.brightPresent
                Layout.fillWidth: true
                Layout.preferredHeight: s(34)
                radius: s(17)
                color: theme.surface0
                clip: true

                opacity: root.revealed ? 1 : 0
                Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 1 * root.stagger } NumberAnimation { duration: root.tBase; easing.type: Easing.OutCubic } } }
                transform: Translate {
                    y: root.revealed ? 0 : root.s(20)
                    Behavior on y { SequentialAnimation { PauseAnimation { duration: 1 * root.stagger } NumberAnimation { duration: 460; easing.type: Easing.OutBack; easing.overshoot: 0.7 } } }
                }

                property bool dragging: false
                property real ratio: root.sysState.brightness / 100

                scale: brightMa.pressed ? 0.985 : 1.0
                Behavior on scale { NumberAnimation { duration: root.tSnap; easing.type: Easing.OutCubic } }

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Math.max(parent.height, parent.width * brightTrack.ratio)
                    radius: parent.radius
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: theme.peach }
                        GradientStop { position: 1.0; color: theme.yellow }
                    }
                    Behavior on width { enabled: !brightTrack.dragging; NumberAnimation { duration: root.tGlide; easing.type: Easing.OutCubic } }
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: s(12)
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰃟"
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: s(16)
                    color: brightTrack.ratio > 0.85 ? theme.crust : theme.text
                    Behavior on color { ColorAnimation { duration: root.tBase } }
                    // Parlaklık arttıkça ikon da büyüsün.
                    scale: 0.9 + brightTrack.ratio * 0.2
                    Behavior on scale { NumberAnimation { duration: root.tGlide; easing.type: Easing.OutCubic } }
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: s(14)
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(brightTrack.ratio * 100) + "%"
                    color: theme.crust
                    font.family: "JetBrains Mono"
                    font.weight: Font.DemiBold
                    font.pixelSize: s(11)
                    opacity: brightTrack.ratio > 0.12 ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: root.tBase } }
                }

                MouseArea {
                    id: brightMa
                    anchors.fill: parent
                    onPressed: (mouse) => { brightTrack.dragging = true; brightTrack.ratio = Math.max(0, Math.min(1, mouse.x / width)); root.runAction("brightness", Math.round(brightTrack.ratio * 100)); }
                    onPositionChanged: (mouse) => { if (pressed) { brightTrack.ratio = Math.max(0, Math.min(1, mouse.x / width)); root.runAction("brightness", Math.round(brightTrack.ratio * 100)); } }
                    onReleased: brightTrack.dragging = false
                }
            }

            // -----------------------------------------------------------
            // VOLUME / MIC
            // -----------------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: s(10)

                opacity: root.revealed ? 1 : 0
                Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 2 * root.stagger } NumberAnimation { duration: root.tBase; easing.type: Easing.OutCubic } } }
                transform: Translate {
                    y: root.revealed ? 0 : root.s(20)
                    Behavior on y { SequentialAnimation { PauseAnimation { duration: 2 * root.stagger } NumberAnimation { duration: 460; easing.type: Easing.OutBack; easing.overshoot: 0.7 } } }
                }

                Text {
                    text: root.sysState.volMuted ? "󰝟" : "󰕾"
                    color: root.sysState.volMuted ? theme.red : theme.text
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: s(15)
                    Behavior on color { ColorAnimation { duration: root.tBase } }
                    scale: volIconMa.pressed ? 0.82 : (volIconMa.containsMouse ? 1.12 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 2.4 } }
                    MouseArea {
                        id: volIconMa
                        anchors.fill: parent; anchors.margins: s(-5)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleWith("volMuted", "volume-mute")
                    }
                }

                Slider {
                    id: volSlider
                    Layout.fillWidth: true
                    from: 0; to: 100
                    implicitHeight: s(24)
                    onMoved: {
                        root.patchState("volume", Math.round(value));
                        root.runAction("volume", Math.round(value));
                    }

                    background: Rectangle {
                        x: volSlider.leftPadding
                        y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                        width: volSlider.availableWidth
                        height: root.s(6)
                        radius: height / 2
                        color: root.alpha(theme.surface1, 0.8)

                        Rectangle {
                            width: volSlider.visualPosition * parent.width
                            height: parent.height
                            radius: parent.radius
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: theme.sapphire }
                                GradientStop { position: 1.0; color: theme.blue }
                            }
                            opacity: root.sysState.volMuted ? 0.3 : 1.0
                            Behavior on opacity { NumberAnimation { duration: root.tBase } }
                            // Sürüklerken animasyon kapalı: kendi hareketini
                            // geciktirip lastik gibi hissettiriyordu.
                            Behavior on width { enabled: !volSlider.pressed; NumberAnimation { duration: root.tGlide; easing.type: Easing.OutCubic } }
                        }
                    }

                    handle: Rectangle {
                        x: volSlider.leftPadding + volSlider.visualPosition * (volSlider.availableWidth - width)
                        y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                        width: root.s(15); height: width
                        radius: width / 2
                        color: theme.text
                        scale: volSlider.pressed ? 1.35 : (volSlider.hovered ? 1.15 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 2.6 } }
                        Behavior on x { enabled: !volSlider.pressed; NumberAnimation { duration: root.tGlide; easing.type: Easing.OutCubic } }
                    }
                }

                Text {
                    text: root.sysState.volume + "%"
                    color: theme.subtext0
                    font.family: "JetBrains Mono"
                    font.pixelSize: s(11)
                    Layout.preferredWidth: s(34)
                    horizontalAlignment: Text.AlignRight
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: s(10)

                opacity: root.revealed ? 1 : 0
                Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 3 * root.stagger } NumberAnimation { duration: root.tBase; easing.type: Easing.OutCubic } } }
                transform: Translate {
                    y: root.revealed ? 0 : root.s(20)
                    Behavior on y { SequentialAnimation { PauseAnimation { duration: 3 * root.stagger } NumberAnimation { duration: 460; easing.type: Easing.OutBack; easing.overshoot: 0.7 } } }
                }

                Text {
                    text: root.sysState.micMuted ? "󰍭" : "󰍬"
                    color: root.sysState.micMuted ? theme.red : theme.text
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: s(15)
                    Behavior on color { ColorAnimation { duration: root.tBase } }
                    scale: micIconMa.pressed ? 0.82 : (micIconMa.containsMouse ? 1.12 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 2.4 } }
                    MouseArea {
                        id: micIconMa
                        anchors.fill: parent; anchors.margins: s(-5)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleWith("micMuted", "mic-mute")
                    }
                }

                Slider {
                    id: micSlider
                    Layout.fillWidth: true
                    from: 0; to: 100
                    implicitHeight: s(24)
                    onMoved: {
                        root.patchState("mic", Math.round(value));
                        root.runAction("mic", Math.round(value));
                    }

                    background: Rectangle {
                        x: micSlider.leftPadding
                        y: micSlider.topPadding + micSlider.availableHeight / 2 - height / 2
                        width: micSlider.availableWidth
                        height: root.s(6)
                        radius: height / 2
                        color: root.alpha(theme.surface1, 0.8)

                        Rectangle {
                            width: micSlider.visualPosition * parent.width
                            height: parent.height
                            radius: parent.radius
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: theme.teal }
                                GradientStop { position: 1.0; color: theme.green }
                            }
                            opacity: root.sysState.micMuted ? 0.3 : 1.0
                            Behavior on opacity { NumberAnimation { duration: root.tBase } }
                            Behavior on width { enabled: !micSlider.pressed; NumberAnimation { duration: root.tGlide; easing.type: Easing.OutCubic } }
                        }
                    }

                    handle: Rectangle {
                        x: micSlider.leftPadding + micSlider.visualPosition * (micSlider.availableWidth - width)
                        y: micSlider.topPadding + micSlider.availableHeight / 2 - height / 2
                        width: root.s(15); height: width
                        radius: width / 2
                        color: theme.text
                        scale: micSlider.pressed ? 1.35 : (micSlider.hovered ? 1.15 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 2.6 } }
                        Behavior on x { enabled: !micSlider.pressed; NumberAnimation { duration: root.tGlide; easing.type: Easing.OutCubic } }
                    }
                }

                Text {
                    text: root.sysState.mic + "%"
                    color: theme.subtext0
                    font.family: "JetBrains Mono"
                    font.pixelSize: s(11)
                    Layout.preferredWidth: s(34)
                    horizontalAlignment: Text.AlignRight
                }
            }

            Connections {
                target: root
                function onSysStateChanged() {
                    if (!volSlider.pressed) volSlider.value = root.sysState.volume;
                    if (!micSlider.pressed) micSlider.value = root.sysState.mic;
                }
            }

            // -----------------------------------------------------------
            // TOGGLE PILLS: Wi-Fi / Bluetooth / EasyEffects
            // -----------------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: s(10)

                opacity: root.revealed ? 1 : 0
                Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 4 * root.stagger } NumberAnimation { duration: root.tBase; easing.type: Easing.OutCubic } } }
                transform: Translate {
                    y: root.revealed ? 0 : root.s(20)
                    Behavior on y { SequentialAnimation { PauseAnimation { duration: 4 * root.stagger } NumberAnimation { duration: 460; easing.type: Easing.OutBack; easing.overshoot: 0.7 } } }
                }

                Repeater {
                    model: [
                        { key: "wifi",  action: "wifi-toggle" },
                        { key: "bt",    action: "bt-toggle" },
                        { key: "eq",    action: "easyeffects-toggle" }
                    ]
                    delegate: Rectangle {
                        id: bigPill

                        readonly property bool isWifi: modelData.key === "wifi"
                        readonly property bool isBt:   modelData.key === "bt"
                        readonly property bool active: isWifi ? root.sysState.wifiOn
                                                     : (isBt ? root.sysState.btOn : root.sysState.easyeffects)
                        readonly property color accent: isWifi ? theme.blue : (isBt ? theme.sapphire : theme.mauve)
                        readonly property string glyph: isWifi
                            ? (active ? "󰤨" : "󰤭")
                            : (isBt ? (active ? (root.sysState.btDevice !== "" ? "󰂱" : "󰂯") : "󰂲") : "󰗀")
                        readonly property string caption: isWifi
                            ? (root.sysState.wifiOn ? (root.sysState.wifiSsid !== "" ? root.sysState.wifiSsid : "On") : "Off")
                            : (isBt ? (root.sysState.btOn ? (root.sysState.btDevice !== "" ? root.sysState.btDevice : "Not connected") : "Off")
                                    : (root.sysState.easyeffects ? "On" : "EasyEffects"))

                        Layout.fillWidth: true
                        Layout.preferredHeight: s(56)
                        radius: s(14)
                        color: active ? root.alpha(accent, 0.16) : root.alpha(theme.surface0, 0.6)
                        border.width: 1
                        border.color: active ? accent : root.alpha(theme.text, 0.08)
                        Behavior on color { ColorAnimation { duration: root.tBase } }
                        Behavior on border.color { ColorAnimation { duration: root.tBase } }

                        scale: bigMa.pressed ? 0.94 : (bigMa.containsMouse ? 1.035 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.8 } }

                        // Aktifleşince dışa doğru dağılan halka. Toggle'ın
                        // gerçekten "tuttuğunu" rengin yanında bir de hareketle
                        // söylüyor; renk geçişi tek başına gözden kaçıyordu.
                        Rectangle {
                            id: bigPing
                            anchors.centerIn: parent
                            width: parent.width; height: parent.height
                            radius: parent.radius
                            color: "transparent"
                            border.width: Math.max(1, root.s(2))
                            border.color: bigPill.accent
                            opacity: 0
                            ParallelAnimation {
                                id: bigPingAnim
                                NumberAnimation { target: bigPing; property: "scale";   from: 1.0;  to: 1.12; duration: 520; easing.type: Easing.OutCubic }
                                NumberAnimation { target: bigPing; property: "opacity"; from: 0.85; to: 0.0;  duration: 520; easing.type: Easing.OutCubic }
                            }
                        }
                        onActiveChanged: if (active) bigPingAnim.restart()

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: s(6)
                            spacing: s(3)

                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: s(3)

                                Text {
                                    text: bigPill.glyph
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: s(18)
                                    color: bigPill.active ? bigPill.accent : theme.subtext0
                                    Behavior on color { ColorAnimation { duration: root.tBase } }

                                    // Wi-Fi kapalıyken bağlanmayı beklemek yerine
                                    // dalgalar duruyor; açıkken hafif nabız atıyor.
                                    SequentialAnimation on scale {
                                        running: bigPill.active && root.visible
                                        loops: Animation.Infinite
                                        alwaysRunToEnd: true
                                        NumberAnimation { to: 1.06; duration: 1400; easing.type: Easing.InOutSine }
                                        NumberAnimation { to: 1.00; duration: 1400; easing.type: Easing.InOutSine }
                                    }
                                }

                                // Wi-Fi ve Bluetooth pill'leri bir de listeyi
                                // açıyor: güç profilindeki chevron ile aynı dil.
                                Text {
                                    visible: bigPill.isWifi || bigPill.isBt
                                    text: "󰅀"
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: s(9)
                                    color: theme.subtext0
                                    rotation: (bigPill.isWifi ? root.wifiOpen : root.btOpen) ? 180 : 0
                                    Behavior on rotation { NumberAnimation { duration: root.tGlide; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: bigPill.caption
                                color: bigPill.active ? theme.text : theme.subtext0
                                font.family: "JetBrains Mono"
                                font.pixelSize: s(10)
                                elide: Text.ElideRight
                                Behavior on color { ColorAnimation { duration: root.tBase } }
                            }
                        }

                        MouseArea {
                            id: bigMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (bigPill.isWifi) {
                                    // Kapalıyken tek tıkla hem aç hem listeyi göster;
                                    // açıkken tıklama sadece listeyi açıp kapatır.
                                    if (!root.sysState.wifiOn) root.toggleWifiRadio();
                                    else                       root.toggleWifiPanel();
                                }
                                else if (bigPill.isBt) {
                                    // Bluetooth'ta da aynı kural: gövde cihaz
                                    // listesini açar, radyo sağ üstteki anahtarda.
                                    if (!root.sysState.btOn) root.toggleBtRadio();
                                    else                     root.toggleBtPanel();
                                }
                                else                     root.toggleWith("easyeffects", "easyeffects-toggle");
                            }
                        }

                        // Radyo anahtarı: gövde listeyi açtığı için Wi-Fi ve
                        // Bluetooth'u kapatmanın yeri burası. bigMa'dan sonra
                        // tanımlı, yani tıklamayı önce o alıyor.
                        Rectangle {
                            visible: bigPill.isWifi || bigPill.isBt
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: s(4)
                            width: s(18); height: s(18)
                            radius: width / 2
                            color: radioMa.containsMouse ? root.alpha(theme.text, 0.12) : "transparent"
                            Behavior on color { ColorAnimation { duration: root.tBase } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰐥"
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: s(10)
                                color: (bigPill.isWifi ? root.sysState.wifiOn : root.sysState.btOn)
                                       ? bigPill.accent : theme.overlay0
                                Behavior on color { ColorAnimation { duration: root.tBase } }
                            }

                            MouseArea {
                                id: radioMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: bigPill.isWifi ? root.toggleWifiRadio() : root.toggleBtRadio()
                            }
                        }
                    }
                }
            }

            // -----------------------------------------------------------
            // WI-FI: ağ listesi (Wi-Fi pill'ine tıklayınca açılır)
            // -----------------------------------------------------------
            Item {
                id: wifiPanel
                Layout.fillWidth: true
                clip: true

                // Liste uzayınca panel tüm sidebar'ı yutmasın: bir tavan koyup
                // gerisini kaydırmaya bırakıyoruz.
                readonly property real maxH: root.s(300)
                property real openH: root.wifiOpen ? Math.min(wifiCol.implicitHeight, maxH) : 0
                Behavior on openH { NumberAnimation { duration: root.tGlide; easing.type: Easing.OutCubic } }
                Layout.preferredHeight: openH
                visible: openH > 0.5

                opacity: root.wifiOpen ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: root.tBase; easing.type: Easing.OutCubic } }

                Flickable {
                    id: wifiFlick
                    anchors.fill: parent
                    contentWidth: width
                    contentHeight: wifiCol.implicitHeight
                    boundsBehavior: Flickable.OvershootBounds
                    flickDeceleration: 3500
                    clip: true

                    ColumnLayout {
                        id: wifiCol
                        width: wifiPanel.width
                        spacing: root.s(6)

                        // --- Başlık: durum + yenile ---
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.bottomMargin: root.s(2)
                            spacing: root.s(6)

                            Text {
                                text: "Ağlar"
                                color: theme.subtext0
                                font.family: "JetBrains Mono"
                                font.pixelSize: root.s(10)
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: root.wifiScanning ? "taranıyor…" : (root.wifiNets.length + " ağ")
                                color: theme.overlay0
                                font.family: "JetBrains Mono"
                                font.pixelSize: root.s(9)
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                width: root.s(24); height: root.s(24)
                                radius: width / 2
                                color: refreshMa.containsMouse ? root.alpha(theme.surface1, 0.8) : "transparent"
                                Behavior on color { ColorAnimation { duration: root.tBase } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰑐"
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: root.s(12)
                                    color: root.wifiScanning ? theme.blue : theme.subtext0
                                    Behavior on color { ColorAnimation { duration: root.tBase } }

                                    RotationAnimator on rotation {
                                        running: root.wifiScanning
                                        loops: Animation.Infinite
                                        from: 0; to: 360
                                        duration: 1100
                                        alwaysRunToEnd: true
                                    }
                                }

                                MouseArea {
                                    id: refreshMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.scanWifi(true)
                                }
                            }
                        }

                        // --- nmcli hata mesajı (yanlış parola vb.) ---
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.wifiError !== "" ? wifiErrText.paintedHeight + root.s(14) : 0
                            visible: root.wifiError !== ""
                            radius: root.s(10)
                            color: root.alpha(theme.red, 0.14)
                            border.width: 1
                            border.color: root.alpha(theme.red, 0.45)

                            Text {
                                id: wifiErrText
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: root.s(10)
                                anchors.rightMargin: root.s(10)
                                text: root.wifiError
                                color: theme.red
                                wrapMode: Text.WordWrap
                                font.family: "JetBrains Mono"
                                font.pixelSize: root.s(9)
                            }
                        }

                        // --- Boş durum ---
                        Text {
                            Layout.fillWidth: true
                            visible: root.wifiNets.length === 0
                            horizontalAlignment: Text.AlignHCenter
                            topPadding: root.s(10); bottomPadding: root.s(10)
                            text: root.sysState.wifiOn
                                  ? (root.wifiScanning ? "Ağlar aranıyor…" : "Ağ bulunamadı")
                                  : "Wi-Fi kapalı"
                            color: theme.overlay0
                            font.family: "JetBrains Mono"
                            font.pixelSize: root.s(10)
                        }

                        // --- Ağ satırları ---
                        Repeater {
                            model: root.wifiNets

                            delegate: Rectangle {
                                id: netRow

                                readonly property var net: modelData
                                readonly property bool expanded: root.wifiExpanded === net.ssid
                                readonly property bool busy: root.wifiBusy === net.ssid
                                readonly property color accent: net.inUse ? theme.green : theme.blue

                                // Satır tıklanınca açılan eylemler, bağlantının
                                // durumuna göre değişiyor.
                                readonly property var actions: {
                                    let a = [];
                                    if (net.inUse) {
                                        a.push({ id: "disconnect", label: "Bağlantıyı kes", icon: "󰖪", tone: "peach" });
                                    } else {
                                        a.push({ id: "connect", label: "Bağlan", icon: "󰤨", tone: "blue" });
                                    }
                                    if (net.saved) a.push({ id: "forget", label: "Ağı unut", icon: "󰩹", tone: "red" });
                                    return a;
                                }

                                function toneColor(t) {
                                    if (t === "red") return theme.red;
                                    if (t === "peach") return theme.peach;
                                    return theme.blue;
                                }

                                Layout.fillWidth: true
                                Layout.preferredHeight: netCol.implicitHeight + root.s(16)
                                Behavior on Layout.preferredHeight { NumberAnimation { duration: root.tGlide; easing.type: Easing.OutCubic } }

                                radius: root.s(12)
                                color: net.inUse ? root.alpha(theme.green, 0.14)
                                                 : ((netMa.containsMouse || expanded) ? root.alpha(theme.surface1, 0.75)
                                                                                      : root.alpha(theme.surface0, 0.5))
                                border.width: 1
                                border.color: net.inUse ? root.alpha(theme.green, 0.8)
                                                        : (expanded ? root.alpha(theme.blue, 0.5) : root.alpha(theme.text, 0.06))
                                Behavior on color { ColorAnimation { duration: root.tBase } }
                                Behavior on border.color { ColorAnimation { duration: root.tBase } }

                                opacity: net.visible ? 1 : 0.55

                                // Satırın tamamı tıklanabilir; eylem düğmeleri
                                // bundan sonra tanımlı olduğu için tıklamayı
                                // önce onlar alıyor.
                                MouseArea {
                                    id: netMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.wifiError = "";
                                        root.wifiExpanded = netRow.expanded ? "" : netRow.net.ssid;
                                    }
                                }

                                ColumnLayout {
                                    id: netCol
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: root.s(8)
                                    spacing: root.s(8)

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: root.s(10)

                                        Text {
                                            text: netRow.net.visible ? root.wifiIcon(netRow.net.signal) : "󰤮"
                                            font.family: "Iosevka Nerd Font"
                                            font.pixelSize: root.s(16)
                                            color: netRow.net.inUse ? theme.green : theme.subtext0
                                            Behavior on color { ColorAnimation { duration: root.tBase } }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 0

                                            Text {
                                                Layout.fillWidth: true
                                                text: netRow.net.ssid
                                                color: netRow.net.inUse ? theme.text : theme.subtext1
                                                font.family: "JetBrains Mono"
                                                font.pixelSize: root.s(11)
                                                font.weight: netRow.net.inUse ? Font.DemiBold : Font.Normal
                                                elide: Text.ElideRight
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                text: netRow.busy ? "bağlanıyor…" : root.wifiRowHint(netRow.net)
                                                color: netRow.busy ? theme.blue : theme.overlay0
                                                font.family: "JetBrains Mono"
                                                font.pixelSize: root.s(9)
                                                elide: Text.ElideRight
                                            }
                                        }

                                        Text {
                                            visible: netRow.net.secured
                                            text: "󰌾"
                                            font.family: "Iosevka Nerd Font"
                                            font.pixelSize: root.s(11)
                                            color: theme.overlay0
                                        }

                                        Text {
                                            text: "󰅀"
                                            font.family: "Iosevka Nerd Font"
                                            font.pixelSize: root.s(9)
                                            color: theme.overlay0
                                            rotation: netRow.expanded ? 180 : 0
                                            Behavior on rotation { NumberAnimation { duration: root.tGlide; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
                                        }
                                    }

                                    // --- Açılan eylem alanı ---
                                    Item {
                                        id: actWrap
                                        Layout.fillWidth: true
                                        clip: true

                                        property real openH: netRow.expanded ? actCol.implicitHeight : 0
                                        Behavior on openH { NumberAnimation { duration: root.tGlide; easing.type: Easing.OutCubic } }
                                        Layout.preferredHeight: openH
                                        visible: openH > 0.5
                                        opacity: netRow.expanded ? 1 : 0
                                        Behavior on opacity { NumberAnimation { duration: root.tBase } }

                                        ColumnLayout {
                                            id: actCol
                                            width: actWrap.width
                                            spacing: root.s(6)

                                            // Parola alanı: korumalı ve bağlı
                                            // olmayan ağlarda. Kayıtlı ağda boş
                                            // bırakılırsa kayıtlı parola kullanılır.
                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: root.s(32)
                                                visible: netRow.net.secured && !netRow.net.inUse
                                                radius: root.s(9)
                                                color: root.alpha(theme.base, 0.55)
                                                border.width: 1
                                                border.color: pwField.activeFocus ? theme.blue : root.alpha(theme.text, 0.1)
                                                Behavior on border.color { ColorAnimation { duration: root.tBase } }

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: root.s(9)
                                                    anchors.rightMargin: root.s(6)
                                                    spacing: root.s(6)

                                                    Text {
                                                        text: "󰌆"
                                                        font.family: "Iosevka Nerd Font"
                                                        font.pixelSize: root.s(12)
                                                        color: pwField.activeFocus ? theme.blue : theme.overlay0
                                                        Behavior on color { ColorAnimation { duration: root.tBase } }
                                                    }

                                                    TextField {
                                                        id: pwField
                                                        Layout.fillWidth: true
                                                        Layout.fillHeight: true
                                                        background: Item {}
                                                        padding: 0
                                                        echoMode: pwReveal.showing ? TextInput.Normal : TextInput.Password
                                                        color: theme.text
                                                        font.family: "JetBrains Mono"
                                                        font.pixelSize: root.s(11)
                                                        placeholderText: netRow.net.saved ? "Kayıtlı parola kullanılacak" : "Parola"
                                                        placeholderTextColor: theme.overlay0
                                                        verticalAlignment: TextInput.AlignVCenter
                                                        onAccepted: root.wifiRun("wifi-connect", netRow.net.ssid, text)
                                                    }

                                                    // Parolayı gör/gizle
                                                    Text {
                                                        id: pwReveal
                                                        property bool showing: false
                                                        text: showing ? "󰛐" : "󰛑"
                                                        font.family: "Iosevka Nerd Font"
                                                        font.pixelSize: root.s(12)
                                                        color: theme.overlay0
                                                        MouseArea {
                                                            anchors.fill: parent
                                                            anchors.margins: -root.s(4)
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: pwReveal.showing = !pwReveal.showing
                                                        }
                                                    }
                                                }
                                            }

                                            // Bağlan / kes / unut
                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: root.s(6)

                                                Repeater {
                                                    model: netRow.actions

                                                    delegate: Rectangle {
                                                        id: actBtn
                                                        readonly property color tone: netRow.toneColor(modelData.tone)

                                                        Layout.fillWidth: true
                                                        Layout.preferredHeight: root.s(30)
                                                        radius: root.s(9)
                                                        color: actBtnMa.containsMouse ? root.alpha(tone, 0.22) : root.alpha(tone, 0.12)
                                                        border.width: 1
                                                        border.color: root.alpha(tone, 0.45)
                                                        Behavior on color { ColorAnimation { duration: root.tBase } }

                                                        opacity: netRow.busy ? 0.5 : 1
                                                        scale: actBtnMa.pressed ? 0.96 : 1.0
                                                        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }

                                                        RowLayout {
                                                            anchors.centerIn: parent
                                                            spacing: root.s(6)

                                                            Text {
                                                                text: modelData.icon
                                                                font.family: "Iosevka Nerd Font"
                                                                font.pixelSize: root.s(12)
                                                                color: actBtn.tone
                                                            }
                                                            Text {
                                                                text: modelData.label
                                                                color: theme.text
                                                                font.family: "JetBrains Mono"
                                                                font.pixelSize: root.s(10)
                                                            }
                                                        }

                                                        MouseArea {
                                                            id: actBtnMa
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            enabled: !netRow.busy
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: {
                                                                const a = modelData.id;
                                                                if (a === "disconnect") {
                                                                    root.wifiRun("wifi-disconnect", netRow.net.ssid);
                                                                } else if (a === "forget") {
                                                                    root.wifiRun("wifi-forget", netRow.net.ssid);
                                                                } else {
                                                                    root.wifiRun("wifi-connect", netRow.net.ssid,
                                                                                 netRow.net.secured ? pwField.text : "");
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }


            // -----------------------------------------------------------
            // BLUETOOTH: cihaz listesi (Bluetooth pill'ine tıklayınca açılır)
            // -----------------------------------------------------------
            Item {
                id: btPanel
                Layout.fillWidth: true
                clip: true

                readonly property real maxH: root.s(300)
                property real openH: root.btOpen ? Math.min(btCol.implicitHeight, maxH) : 0
                Behavior on openH { NumberAnimation { duration: root.tGlide; easing.type: Easing.OutCubic } }
                Layout.preferredHeight: openH
                visible: openH > 0.5

                opacity: root.btOpen ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: root.tBase; easing.type: Easing.OutCubic } }

                Flickable {
                    id: btFlick
                    anchors.fill: parent
                    contentWidth: width
                    contentHeight: btCol.implicitHeight
                    boundsBehavior: Flickable.OvershootBounds
                    flickDeceleration: 3500
                    clip: true

                    ColumnLayout {
                        id: btCol
                        width: btPanel.width
                        spacing: root.s(6)

                        // --- Başlık: durum + tarama anahtarı ---
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.bottomMargin: root.s(2)
                            spacing: root.s(6)

                            Text {
                                text: "Cihazlar"
                                color: theme.subtext0
                                font.family: "JetBrains Mono"
                                font.pixelSize: root.s(10)
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: root.btDiscovering ? "aranıyor…" : (root.btDevices.length + " cihaz")
                                color: theme.overlay0
                                font.family: "JetBrains Mono"
                                font.pixelSize: root.s(9)
                            }

                            Item { Layout.fillWidth: true }

                            // Wi-Fi'de "yenile" olan yer burada "ara/durdur":
                            // bluez'de kesif kendiliginden dönmez, açık tutmak
                            // gerekir ve açık kalması pili yer.
                            Rectangle {
                                width: root.s(24); height: root.s(24)
                                radius: width / 2
                                color: btScanMa.containsMouse ? root.alpha(theme.surface1, 0.8) : "transparent"
                                Behavior on color { ColorAnimation { duration: root.tBase } }

                                Text {
                                    anchors.centerIn: parent
                                    text: root.btDiscovering ? "󰓛" : "󰐷"
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: root.s(12)
                                    color: root.btDiscovering ? theme.sapphire : theme.subtext0
                                    Behavior on color { ColorAnimation { duration: root.tBase } }

                                    SequentialAnimation on opacity {
                                        running: root.btDiscovering
                                        loops: Animation.Infinite
                                        alwaysRunToEnd: true
                                        NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutSine }
                                        NumberAnimation { to: 1.0;  duration: 700; easing.type: Easing.InOutSine }
                                    }
                                }

                                MouseArea {
                                    id: btScanMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.btToggleScan()
                                }
                            }
                        }

                        // --- bluetoothctl hata mesajı ---
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.btError !== "" ? btErrText.paintedHeight + root.s(14) : 0
                            visible: root.btError !== ""
                            radius: root.s(10)
                            color: root.alpha(theme.red, 0.14)
                            border.width: 1
                            border.color: root.alpha(theme.red, 0.45)

                            Text {
                                id: btErrText
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: root.s(10)
                                anchors.rightMargin: root.s(10)
                                text: root.btError
                                color: theme.red
                                wrapMode: Text.WordWrap
                                font.family: "JetBrains Mono"
                                font.pixelSize: root.s(9)
                            }
                        }

                        // --- Boş durum ---
                        Text {
                            Layout.fillWidth: true
                            visible: root.btDevices.length === 0
                            horizontalAlignment: Text.AlignHCenter
                            topPadding: root.s(10); bottomPadding: root.s(10)
                            wrapMode: Text.WordWrap
                            text: !root.sysState.btOn
                                  ? "Bluetooth kapalı"
                                  : (root.btDiscovering
                                     ? "Cihaz aranıyor — eşleştirmek istediğinizi keşfedilebilir moda alın"
                                     : "Cihaz yok. Aramayı başlatmak için 󰐷 düğmesine basın.")
                            color: theme.overlay0
                            font.family: "JetBrains Mono"
                            font.pixelSize: root.s(10)
                        }

                        // --- Cihaz satırları ---
                        Repeater {
                            model: root.btDevices

                            delegate: Rectangle {
                                id: devRow

                                readonly property var dev: modelData
                                readonly property bool expanded: root.btExpanded === dev.mac
                                readonly property bool busy: root.btBusy === dev.mac
                                readonly property color accent: dev.connected ? theme.green : theme.sapphire

                                readonly property var actions: {
                                    let a = [];
                                    if (dev.connected) {
                                        a.push({ id: "disconnect", label: "Bağlantıyı kes", icon: "󰂲", tone: "peach" });
                                    } else if (dev.paired) {
                                        a.push({ id: "connect", label: "Bağlan", icon: "󰂯", tone: "blue" });
                                    } else {
                                        // Eşleşmemiş cihazda tek adım: script
                                        // eşleştirip güven verip bağlanıyor.
                                        a.push({ id: "connect", label: "Eşleştir ve bağlan", icon: "󰐷", tone: "blue" });
                                    }
                                    if (dev.paired) a.push({ id: "remove", label: "Kaldır", icon: "󰩹", tone: "red" });
                                    return a;
                                }

                                function toneColor(t) {
                                    if (t === "red") return theme.red;
                                    if (t === "peach") return theme.peach;
                                    return theme.sapphire;
                                }

                                Layout.fillWidth: true
                                Layout.preferredHeight: devCol.implicitHeight + root.s(16)
                                Behavior on Layout.preferredHeight { NumberAnimation { duration: root.tGlide; easing.type: Easing.OutCubic } }

                                radius: root.s(12)
                                color: dev.connected ? root.alpha(theme.green, 0.14)
                                                     : ((devMa.containsMouse || expanded) ? root.alpha(theme.surface1, 0.75)
                                                                                          : root.alpha(theme.surface0, 0.5))
                                border.width: 1
                                border.color: dev.connected ? root.alpha(theme.green, 0.8)
                                                            : (expanded ? root.alpha(theme.sapphire, 0.5) : root.alpha(theme.text, 0.06))
                                Behavior on color { ColorAnimation { duration: root.tBase } }
                                Behavior on border.color { ColorAnimation { duration: root.tBase } }

                                // Adı olmayan cihazlar (bluez MAC'i ad olarak
                                // veriyor) listeyi doldurmasın diye soluk.
                                opacity: dev.paired || dev.connected || dev.name !== dev.mac.replace(/:/g, "-") ? 1 : 0.6

                                MouseArea {
                                    id: devMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.btError = "";
                                        root.btExpanded = devRow.expanded ? "" : devRow.dev.mac;
                                    }
                                }

                                ColumnLayout {
                                    id: devCol
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: root.s(8)
                                    spacing: root.s(8)

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: root.s(10)

                                        Text {
                                            text: root.btIcon(devRow.dev.name)
                                            font.family: "Iosevka Nerd Font"
                                            font.pixelSize: root.s(16)
                                            color: devRow.dev.connected ? theme.green : theme.subtext0
                                            Behavior on color { ColorAnimation { duration: root.tBase } }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 0

                                            Text {
                                                Layout.fillWidth: true
                                                text: devRow.dev.name
                                                color: devRow.dev.connected ? theme.text : theme.subtext1
                                                font.family: "JetBrains Mono"
                                                font.pixelSize: root.s(11)
                                                font.weight: devRow.dev.connected ? Font.DemiBold : Font.Normal
                                                elide: Text.ElideRight
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                text: devRow.busy ? "işleniyor…" : root.btRowHint(devRow.dev)
                                                color: devRow.busy ? theme.sapphire : theme.overlay0
                                                font.family: "JetBrains Mono"
                                                font.pixelSize: root.s(9)
                                                elide: Text.ElideRight
                                            }
                                        }

                                        Text {
                                            visible: devRow.dev.paired
                                            text: "󰁪"
                                            font.family: "Iosevka Nerd Font"
                                            font.pixelSize: root.s(11)
                                            color: theme.overlay0
                                        }

                                        Text {
                                            text: "󰅀"
                                            font.family: "Iosevka Nerd Font"
                                            font.pixelSize: root.s(9)
                                            color: theme.overlay0
                                            rotation: devRow.expanded ? 180 : 0
                                            Behavior on rotation { NumberAnimation { duration: root.tGlide; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
                                        }
                                    }

                                    // --- Açılan eylem alanı ---
                                    Item {
                                        id: devActWrap
                                        Layout.fillWidth: true
                                        clip: true

                                        property real openH: devRow.expanded ? devActCol.implicitHeight : 0
                                        Behavior on openH { NumberAnimation { duration: root.tGlide; easing.type: Easing.OutCubic } }
                                        Layout.preferredHeight: openH
                                        visible: openH > 0.5
                                        opacity: devRow.expanded ? 1 : 0
                                        Behavior on opacity { NumberAnimation { duration: root.tBase } }

                                        ColumnLayout {
                                            id: devActCol
                                            width: devActWrap.width
                                            spacing: root.s(6)

                                            Text {
                                                Layout.fillWidth: true
                                                text: devRow.dev.mac
                                                color: theme.overlay0
                                                font.family: "JetBrains Mono"
                                                font.pixelSize: root.s(9)
                                                elide: Text.ElideRight
                                            }

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: root.s(6)

                                                Repeater {
                                                    model: devRow.actions

                                                    delegate: Rectangle {
                                                        id: devActBtn
                                                        readonly property color tone: devRow.toneColor(modelData.tone)

                                                        Layout.fillWidth: true
                                                        Layout.preferredHeight: root.s(30)
                                                        radius: root.s(9)
                                                        color: devActMa.containsMouse ? root.alpha(tone, 0.22) : root.alpha(tone, 0.12)
                                                        border.width: 1
                                                        border.color: root.alpha(tone, 0.45)
                                                        Behavior on color { ColorAnimation { duration: root.tBase } }

                                                        opacity: devRow.busy ? 0.5 : 1
                                                        scale: devActMa.pressed ? 0.96 : 1.0
                                                        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }

                                                        RowLayout {
                                                            anchors.centerIn: parent
                                                            spacing: root.s(6)

                                                            Text {
                                                                text: modelData.icon
                                                                font.family: "Iosevka Nerd Font"
                                                                font.pixelSize: root.s(12)
                                                                color: devActBtn.tone
                                                            }
                                                            Text {
                                                                text: modelData.label
                                                                color: theme.text
                                                                font.family: "JetBrains Mono"
                                                                font.pixelSize: root.s(10)
                                                                elide: Text.ElideRight
                                                            }
                                                        }

                                                        MouseArea {
                                                            id: devActMa
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            enabled: !devRow.busy
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: root.btRun(modelData.id, devRow.dev.mac)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // -----------------------------------------------------------
            // TOGGLE ICONS: power profile / keep awake / DND / night light
            // -----------------------------------------------------------
            Item {
                id: quickEditPanel
                Layout.fillWidth: true
                clip: true

                property real openH: root.editMode ? quickEditColumn.implicitHeight : 0
                Layout.preferredHeight: openH
                visible: openH > 0.5
                opacity: root.editMode ? 1 : 0
                Behavior on openH { NumberAnimation { duration: root.tGlide; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: root.tBase; easing.type: Easing.OutCubic } }

                Rectangle {
                    anchors.fill: parent
                    radius: s(16)
                    color: root.alpha(theme.surface0, 0.72)
                    border.width: 1
                    border.color: root.alpha(theme.teal, root.editMode ? 0.38 : 0.12)
                    Behavior on border.color { ColorAnimation { duration: root.tBase } }
                }

                ColumnLayout {
                    id: quickEditColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: s(12)
                    spacing: s(9)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: s(8)

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                text: "Hızlı ayarları özelleştir"
                                color: theme.text
                                font.family: "JetBrains Mono"
                                font.weight: Font.DemiBold
                                font.pixelSize: s(11)
                            }
                            Text {
                                text: "Bu alan sidebar içinde kalır"
                                color: theme.overlay0
                                font.family: "JetBrains Mono"
                                font.pixelSize: s(9)
                            }
                        }

                        Text {
                            text: "󰄬"
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: s(15)
                            color: theme.teal
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: s(-6)
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.editMode = false
                            }
                        }
                    }

                    Text {
                        text: "AKTİF"
                        color: theme.teal
                        font.family: "JetBrains Mono"
                        font.weight: Font.DemiBold
                        font.pixelSize: s(9)
                    }

                    Flow {
                        id: selectedQuickActions
                        Layout.fillWidth: true
                        Layout.preferredHeight: childrenRect.height
                        spacing: s(6)

                        Repeater {
                            model: root.quickActionIds
                            delegate: Rectangle {
                                readonly property var item: root.quickActionDefinition(modelData)
                                width: Math.max(s(116), selectedLabel.implicitWidth + s(82))
                                height: s(32)
                                radius: s(10)
                                color: root.alpha(root.quickActionAccent(item), 0.12)
                                border.width: 1
                                border.color: root.alpha(root.quickActionAccent(item), 0.34)

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: s(8)
                                    anchors.rightMargin: s(5)
                                    spacing: s(4)

                                    Text {
                                        text: item ? item.icon : ""
                                        color: root.quickActionAccent(item)
                                        font.family: "Iosevka Nerd Font"
                                        font.pixelSize: s(13)
                                    }
                                    Text {
                                        id: selectedLabel
                                        Layout.fillWidth: true
                                        text: item ? item.label : ""
                                        color: theme.text
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: s(9)
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        text: "󰁮"
                                        color: index > 0 ? theme.subtext0 : theme.surface2
                                        font.family: "Iosevka Nerd Font"
                                        font.pixelSize: s(11)
                                        MouseArea {
                                            anchors.fill: parent
                                            anchors.margins: s(-4)
                                            enabled: index > 0
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.moveQuickAction(modelData, -1)
                                        }
                                    }
                                    Text {
                                        text: "󰁅"
                                        color: index < root.quickActionIds.length - 1 ? theme.subtext0 : theme.surface2
                                        font.family: "Iosevka Nerd Font"
                                        font.pixelSize: s(11)
                                        MouseArea {
                                            anchors.fill: parent
                                            anchors.margins: s(-4)
                                            enabled: index < root.quickActionIds.length - 1
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.moveQuickAction(modelData, 1)
                                        }
                                    }
                                    Text {
                                        text: "󰅖"
                                        color: removeMa.containsMouse ? theme.red : theme.overlay0
                                        font.family: "Iosevka Nerd Font"
                                        font.pixelSize: s(11)
                                        MouseArea {
                                            id: removeMa
                                            anchors.fill: parent
                                            anchors.margins: s(-4)
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.removeQuickAction(modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        text: "EKLENEBİLİR"
                        color: theme.teal
                        font.family: "JetBrains Mono"
                        font.weight: Font.DemiBold
                        font.pixelSize: s(9)
                        Layout.topMargin: s(2)
                    }

                    Flow {
                        id: availableQuickActions
                        Layout.fillWidth: true
                        Layout.preferredHeight: childrenRect.height
                        spacing: s(6)

                        Repeater {
                            model: root.availableQuickActions()
                            delegate: Rectangle {
                                readonly property var item: modelData
                                width: addLabel.implicitWidth + s(30)
                                height: s(29)
                                radius: s(9)
                                color: addMa.containsMouse ? root.alpha(theme.teal, 0.16) : root.alpha(theme.surface1, 0.72)
                                border.width: 1
                                border.color: addMa.containsMouse ? root.alpha(theme.teal, 0.60) : root.alpha(theme.text, 0.08)
                                Behavior on color { ColorAnimation { duration: root.tBase } }
                                Behavior on border.color { ColorAnimation { duration: root.tBase } }

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: s(5)
                                    Text { text: "󰐕"; color: theme.teal; font.family: "Iosevka Nerd Font"; font.pixelSize: s(11) }
                                    Text {
                                        id: addLabel
                                        text: item ? item.label : ""
                                        color: addMa.containsMouse ? theme.text : theme.subtext0
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: s(9)
                                    }
                                }

                                MouseArea {
                                    id: addMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.addQuickAction(item.id)
                                }
                            }
                        }
                    }

                    Text {
                        visible: root.availableQuickActions().length === 0
                        text: "Tüm hızlı ayarlar aktif"
                        color: theme.overlay0
                        font.family: "JetBrains Mono"
                        font.pixelSize: s(9)
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Ekle: +   ·   Sırala: ↑ ↓   ·   Kaldır: ×"
                        color: theme.overlay0
                        font.family: "JetBrains Mono"
                        font.pixelSize: s(8)
                        opacity: 0.78
                    }
                }
            }

            RowLayout {
                id: toggleRow
                Layout.fillWidth: true
                spacing: s(10)
                visible: !root.editMode

                opacity: root.revealed ? 1 : 0
                Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 5 * root.stagger } NumberAnimation { duration: root.tBase; easing.type: Easing.OutCubic } } }
                transform: Translate {
                    y: root.revealed ? 0 : root.s(20)
                    Behavior on y { SequentialAnimation { PauseAnimation { duration: 5 * root.stagger } NumberAnimation { duration: 460; easing.type: Easing.OutBack; easing.overshoot: 0.7 } } }
                }

                // --- Güç profili: artık kör kör cycle etmiyor, seçenekleri açıyor ---
                Rectangle {
                    id: profilePill
                    readonly property color accent: root.profileColor(root.sysState.profile)

                    Layout.fillWidth: true
                    Layout.preferredHeight: s(52)
                    radius: s(14)
                    color: root.profileOpen ? root.alpha(accent, 0.22) : root.alpha(accent, 0.12)
                    border.width: 1
                    border.color: root.profileOpen ? accent : root.alpha(accent, 0.45)
                    Behavior on color { ColorAnimation { duration: root.tBase } }
                    Behavior on border.color { ColorAnimation { duration: root.tBase } }

                    scale: profileMa.pressed ? 0.94 : (profileMa.containsMouse ? 1.035 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.8 } }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: s(4)
                        spacing: s(2)

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: s(3)
                            Text {
                                text: root.profileIcon(root.sysState.profile)
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: s(17)
                                color: profilePill.accent
                                Behavior on color { ColorAnimation { duration: root.tBase } }
                            }
                            Text {
                                // Panel açıkken chevron yukarı döner.
                                text: "󰅀"
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: s(9)
                                color: theme.subtext0
                                rotation: root.profileOpen ? 180 : 0
                                Behavior on rotation { NumberAnimation { duration: root.tGlide; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: root.profileName(root.sysState.profile)
                            color: theme.subtext0
                            font.family: "JetBrains Mono"
                            font.pixelSize: s(9)
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: profileMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.profileOpen = !root.profileOpen;
                            if (root.profileOpen) root.powerOpen = false;
                        }
                    }
                }

                Repeater {
                    model: root.quickActionIds
                    delegate: Rectangle {
                        id: togglePill
                        readonly property var item: root.quickActionDefinition(modelData)
                        readonly property bool active: root.quickActionActive(item)
                        readonly property color accent: root.quickActionAccent(item)

                        Layout.fillWidth: true
                        Layout.preferredHeight: s(52)
                        radius: s(14)
                        color: active ? root.alpha(accent, 0.16) : root.alpha(theme.surface0, 0.6)
                        border.width: 1
                        border.color: active ? accent : root.alpha(theme.text, 0.08)
                        Behavior on color { ColorAnimation { duration: root.tBase } }
                        Behavior on border.color { ColorAnimation { duration: root.tBase } }

                        scale: toggleMa.pressed ? 0.94 : (toggleMa.containsMouse ? 1.035 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.8 } }

                        Rectangle {
                            id: togglePing
                            anchors.centerIn: parent
                            width: parent.width; height: parent.height
                            radius: parent.radius
                            color: "transparent"
                            border.width: Math.max(1, root.s(2))
                            border.color: togglePill.accent
                            opacity: 0
                            ParallelAnimation {
                                id: togglePingAnim
                                NumberAnimation { target: togglePing; property: "scale";   from: 1.0;  to: 1.14; duration: 520; easing.type: Easing.OutCubic }
                                NumberAnimation { target: togglePing; property: "opacity"; from: 0.85; to: 0.0;  duration: 520; easing.type: Easing.OutCubic }
                            }
                        }
                        onActiveChanged: if (active) togglePingAnim.restart()

                        // Awake açıkken düz renk değişimi gözden kolayca
                        // kaçıyordu (uzun süre aktif kalan tek toggle bu) —
                        // sürekli nefes alan bir kenarlık onu diğerlerinden
                        // ayırt edilir kılıyor.
                        Rectangle {
                            id: awakeGlow
                            visible: modelData.key === "inhibit" && togglePill.active
                            anchors.fill: parent
                            radius: parent.radius
                            color: "transparent"
                            border.width: Math.max(1, root.s(2))
                            border.color: togglePill.accent
                            opacity: 0.15
                            SequentialAnimation on opacity {
                                running: awakeGlow.visible
                                loops: Animation.Infinite
                                NumberAnimation { from: 0.15; to: 0.7; duration: 900; easing.type: Easing.InOutSine }
                                NumberAnimation { from: 0.7; to: 0.15; duration: 900; easing.type: Easing.InOutSine }
                            }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: s(4)
                            spacing: s(2)
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: item ? item.icon : ""
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: s(17)
                                color: togglePill.active ? togglePill.accent : theme.subtext0
                                Behavior on color { ColorAnimation { duration: root.tBase } }
                                rotation: togglePill.active ? 0 : -8
                                Behavior on rotation { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }
                            }
                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: item ? item.label : ""
                                color: togglePill.active ? theme.text : theme.subtext0
                                font.family: "JetBrains Mono"
                                font.pixelSize: s(9)
                                elide: Text.ElideRight
                                Behavior on color { ColorAnimation { duration: root.tBase } }
                            }
                        }

                        MouseArea {
                            id: toggleMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activateQuickAction(item)
                        }
                    }
                }
            }

            // -----------------------------------------------------------
            // POWER PROFILE PICKER (profil pilinden açılır)
            // -----------------------------------------------------------
            Item {
                id: profilePanel
                Layout.fillWidth: true
                clip: true

                // Behavior doğrudan `Layout.preferredHeight` üzerine
                // konulamıyor (attached property), o yüzden animasyonu normal
                // bir property üzerinde yürütüp layout'a onu bağlıyoruz.
                property real openH: root.profileOpen ? profileCol.implicitHeight : 0
                Behavior on openH { NumberAnimation { duration: root.tGlide; easing.type: Easing.OutCubic } }
                Layout.preferredHeight: openH

                // Kapalıyken tamamen görünmez olmalı: ColumnLayout 0 yükseklikli
                // ama görünür bir çocuğun etrafına yine de spacing koyuyor, bu da
                // panel kapalıyken açıklanamayan bir boşluk bırakıyordu.
                visible: openH > 0.5

                opacity: root.profileOpen ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: root.tBase; easing.type: Easing.OutCubic } }

                ColumnLayout {
                    id: profileCol
                    width: parent.width
                    spacing: s(6)

                    Repeater {
                        model: root.sysState.profiles

                        delegate: Rectangle {
                            id: profOpt
                            readonly property bool selected: root.sysState.profile === modelData
                            readonly property color accent: root.profileColor(modelData)

                            Layout.fillWidth: true
                            Layout.preferredHeight: s(46)
                            radius: s(12)
                            color: selected ? root.alpha(accent, 0.18)
                                            : (profOptMa.containsMouse ? root.alpha(theme.surface1, 0.75)
                                                                       : root.alpha(theme.surface0, 0.5))
                            border.width: 1
                            border.color: selected ? accent : root.alpha(theme.text, 0.06)
                            Behavior on color { ColorAnimation { duration: root.tBase } }
                            Behavior on border.color { ColorAnimation { duration: root.tBase } }

                            scale: profOptMa.pressed ? 0.97 : 1.0
                            Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }

                            // Panel açılırken satırlar sırayla soldan süzülür.
                            opacity: root.profileOpen ? 1 : 0
                            Behavior on opacity { SequentialAnimation { PauseAnimation { duration: index * 55 } NumberAnimation { duration: root.tBase; easing.type: Easing.OutCubic } } }
                            transform: Translate {
                                x: root.profileOpen ? 0 : root.s(-18)
                                Behavior on x { SequentialAnimation { PauseAnimation { duration: index * 55 } NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.1 } } }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: s(12)
                                anchors.rightMargin: s(12)
                                spacing: s(10)

                                Text {
                                    text: root.profileIcon(modelData)
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: s(17)
                                    color: profOpt.selected ? profOpt.accent : theme.subtext0
                                    Behavior on color { ColorAnimation { duration: root.tBase } }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Text {
                                        Layout.fillWidth: true
                                        text: root.profileName(modelData)
                                        color: profOpt.selected ? theme.text : theme.subtext0
                                        font.family: "JetBrains Mono"
                                        font.weight: profOpt.selected ? Font.DemiBold : Font.Normal
                                        font.pixelSize: s(11)
                                        elide: Text.ElideRight
                                        Behavior on color { ColorAnimation { duration: root.tBase } }
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: root.profileHint(modelData)
                                        color: theme.overlay0
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: s(9)
                                        elide: Text.ElideRight
                                    }
                                }

                                Text {
                                    text: "󰄬"
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: s(13)
                                    color: profOpt.accent
                                    opacity: profOpt.selected ? 1 : 0
                                    scale: profOpt.selected ? 1 : 0.5
                                    Behavior on opacity { NumberAnimation { duration: root.tBase } }
                                    Behavior on scale { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 2.6 } }
                                }
                            }

                            MouseArea {
                                id: profOptMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setProfile(modelData)
                            }
                        }
                    }
                }
            }

            // -----------------------------------------------------------
            // SCROLLABLE: notifications + calendar
            // -----------------------------------------------------------
            Flickable {
                id: scrollArea
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: scrollContent.implicitHeight
                boundsBehavior: Flickable.OvershootBounds
                flickDeceleration: 3500
                maximumFlickVelocity: 3000

                opacity: root.revealed ? 1 : 0
                Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 6 * root.stagger } NumberAnimation { duration: root.tBase; easing.type: Easing.OutCubic } } }
                transform: Translate {
                    y: root.revealed ? 0 : root.s(20)
                    Behavior on y { SequentialAnimation { PauseAnimation { duration: 6 * root.stagger } NumberAnimation { duration: 460; easing.type: Easing.OutBack; easing.overshoot: 0.7 } } }
                }

                ScrollBar.vertical: ScrollBar {
                    id: vbar
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        implicitWidth: root.s(4)
                        radius: width / 2
                        color: vbar.pressed ? theme.overlay1 : theme.surface2
                        opacity: vbar.active ? 0.9 : 0.0
                        Behavior on opacity { NumberAnimation { duration: root.tBase } }
                        Behavior on color { ColorAnimation { duration: root.tBase } }
                    }
                }

                ColumnLayout {
                    id: scrollContent
                    width: parent.width
                    spacing: s(16)

                    // --- Notifications header ---
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: s(6)
                        Text { text: "󰂚"; font.family: "Iosevka Nerd Font"; font.pixelSize: s(13); color: theme.subtext0 }
                        Text { text: (root.notifModel ? root.notifModel.count : 0) + " notifications"; color: theme.subtext0; font.family: "JetBrains Mono"; font.pixelSize: s(12) }
                        Item { Layout.fillWidth: true }
                        Text {
                            visible: root.notifModel && root.notifModel.count > 0
                            text: "󰆴"
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: s(13)
                            color: clearMa.containsMouse ? theme.red : theme.subtext0
                            Behavior on color { ColorAnimation { duration: root.tBase } }
                            scale: clearMa.pressed ? 0.8 : (clearMa.containsMouse ? 1.15 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 2.4 } }
                            MouseArea { id: clearMa; anchors.fill: parent; anchors.margins: s(-6); hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clearNotifications() }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: !root.notifModel || root.notifModel.count === 0
                        text: "No notifications"
                        horizontalAlignment: Text.AlignHCenter
                        color: theme.overlay0
                        font.family: "JetBrains Mono"
                        font.pixelSize: s(12)
                    }

                    Repeater {
                        model: root.notifModel
                        delegate: Rectangle {
                            id: notifCard
                            Layout.fillWidth: true
                            Layout.preferredHeight: notifCol.implicitHeight + s(20)
                            radius: s(12)
                            color: notifMa.containsMouse ? root.alpha(theme.surface1, 0.55) : root.alpha(theme.surface0, 0.6)
                            Behavior on color { ColorAnimation { duration: root.tBase } }

                            property var actionArray: {
                                try { return actionsJson ? JSON.parse(Qt.atob(actionsJson)) : []; } catch (e) { return []; }
                            }
                            property string resolvedIcon: root.resolveAppIcon(appName, iconPath)

                            // Yeni kart listeye eklendiğinde yerine oturarak gelir.
                            opacity: 0
                            scale: 0.96
                            Component.onCompleted: cardIntro.start()
                            ParallelAnimation {
                                id: cardIntro
                                NumberAnimation { target: notifCard; property: "opacity"; to: 1.0; duration: root.tBase; easing.type: Easing.OutCubic }
                                NumberAnimation { target: notifCard; property: "scale";   to: 1.0; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                            }

                            // Kart gövdesi de tıklanabilir olmadığı için sadece
                            // hover'ı yakalıyoruz; üstteki kapat/aksiyon
                            // MouseArea'ları bunun önünde kalıyor.
                            MouseArea { id: notifMa; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }

                            ColumnLayout {
                                id: notifCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: s(10)
                                spacing: s(3)

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: s(6)

                                    Item {
                                        Layout.preferredWidth: s(18)
                                        Layout.preferredHeight: s(18)

                                        Image {
                                            id: notifAppIcon
                                            anchors.fill: parent
                                            source: notifCard.resolvedIcon
                                            fillMode: Image.PreserveAspectFit
                                            asynchronous: true
                                            visible: notifCard.resolvedIcon !== "" && status === Image.Ready
                                            smooth: true
                                        }
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: s(5)
                                            color: theme.surface1
                                            visible: !notifAppIcon.visible
                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰂚"
                                                font.family: "Iosevka Nerd Font"
                                                font.pixelSize: s(11)
                                                color: theme.mauve
                                            }
                                        }
                                    }

                                    Text { text: appName || "System"; color: theme.mauve; font.family: "JetBrains Mono"; font.weight: Font.DemiBold; font.pixelSize: s(11); Layout.fillWidth: true; elide: Text.ElideRight }
                                    Text { text: root.timeAgo(timestamp); color: theme.overlay0; font.family: "JetBrains Mono"; font.pixelSize: s(10) }
                                    Text {
                                        text: "󰅖"
                                        font.family: "Iosevka Nerd Font"
                                        font.pixelSize: s(11)
                                        color: dismissMa.containsMouse ? theme.red : theme.overlay0
                                        Behavior on color { ColorAnimation { duration: root.tBase } }
                                        scale: dismissMa.pressed ? 0.75 : (dismissMa.containsMouse ? 1.2 : 1.0)
                                        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 2.6 } }
                                        MouseArea { id: dismissMa; anchors.fill: parent; anchors.margins: s(-5); hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.dismissNotificationAt(index) }
                                    }
                                }
                                Text { text: summary || ""; color: theme.text; font.family: "JetBrains Mono"; font.pixelSize: s(12); Layout.fillWidth: true; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight }
                                Text { text: body || ""; color: theme.subtext0; font.family: "JetBrains Mono"; font.pixelSize: s(11); Layout.fillWidth: true; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight; visible: (body || "") !== "" }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.topMargin: notifCard.actionArray.length > 0 ? s(4) : 0
                                    spacing: s(6)
                                    visible: notifCard.actionArray.length > 0

                                    Repeater {
                                        model: notifCard.actionArray
                                        delegate: Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: s(26)
                                            radius: s(8)
                                            color: actMa.containsMouse ? theme.surface2 : theme.surface1
                                            Behavior on color { ColorAnimation { duration: root.tBase } }
                                            scale: actMa.pressed ? 0.95 : 1.0
                                            Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }

                                            Text { anchors.centerIn: parent; text: modelData.text || "Action"; color: theme.text; font.family: "JetBrains Mono"; font.pixelSize: s(10) }

                                            MouseArea {
                                                id: actMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    let n = root.liveNotifs ? root.liveNotifs[uid] : null;
                                                    if (n && n.actions) {
                                                        for (let i = 0; i < n.actions.length; i++) {
                                                            if (n.actions[i].identifier === modelData.id) {
                                                                n.actions[i].invoke();
                                                                break;
                                                            }
                                                        }
                                                    }
                                                    Qt.callLater(function() { root.dismissNotificationAt(index); });
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // --- Calendar ---
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: s(4)
                        spacing: s(10)

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: ""
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: s(14)
                                color: calPrevMa.containsMouse ? theme.text : theme.subtext0
                                Behavior on color { ColorAnimation { duration: root.tBase } }
                                scale: calPrevMa.pressed ? 0.75 : (calPrevMa.containsMouse ? 1.2 : 1.0)
                                Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 2.6 } }
                                MouseArea { id: calPrevMa; anchors.fill: parent; anchors.margins: s(-6); hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.stepMonth(-1) }
                            }
                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: root.monthLabel
                                color: theme.text
                                font.family: "JetBrains Mono"
                                font.weight: Font.Bold
                                font.pixelSize: s(13)
                            }
                            Text {
                                text: ""
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: s(14)
                                color: calNextMa.containsMouse ? theme.text : theme.subtext0
                                Behavior on color { ColorAnimation { duration: root.tBase } }
                                scale: calNextMa.pressed ? 0.75 : (calNextMa.containsMouse ? 1.2 : 1.0)
                                Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 2.6 } }
                                MouseArea { id: calNextMa; anchors.fill: parent; anchors.margins: s(-6); hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.stepMonth(1) }
                            }
                        }

                        // Ay geçişinde kayan gövde. `x` doğrudan animate
                        // edilemiyor çünkü ColumnLayout konumu her frame geri
                        // yazar — bu yüzden kaydırma bir Translate üzerinden.
                        Item {
                            id: calBody
                            Layout.fillWidth: true
                            Layout.preferredHeight: calInner.implicitHeight
                            transform: Translate { id: calBodyShift; x: 0 }

                            ColumnLayout {
                                id: calInner
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                spacing: s(10)

                                RowLayout {
                                    Layout.fillWidth: true
                                    Repeater {
                                        model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                                        Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: modelData; color: theme.overlay0; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: s(10) }
                                    }
                                }

                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 7
                                    rowSpacing: s(4)
                                    columnSpacing: s(4)

                                    Repeater {
                                        model: calendarModel
                                        delegate: Rectangle {
                                            id: dayCell
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: s(28)
                                            radius: s(8)
                                            color: isToday ? theme.mauve : (dayMa.containsMouse ? root.alpha(theme.surface2, 0.5) : "transparent")
                                            Behavior on color { ColorAnimation { duration: root.tBase } }

                                            scale: dayMa.containsMouse ? 1.14 : 1.0
                                            Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 2.6 } }

                                            // Bugünün etrafında yavaş nefes alan halka.
                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: parent.width; height: parent.height
                                                radius: parent.radius
                                                color: "transparent"
                                                border.width: Math.max(1, root.s(1))
                                                border.color: theme.mauve
                                                visible: isToday
                                                SequentialAnimation on opacity {
                                                    running: isToday && root.visible
                                                    loops: Animation.Infinite
                                                    alwaysRunToEnd: true
                                                    NumberAnimation { to: 0.0; duration: 1600; easing.type: Easing.InOutSine }
                                                    NumberAnimation { to: 0.6; duration: 1600; easing.type: Easing.InOutSine }
                                                }
                                                SequentialAnimation on scale {
                                                    running: isToday && root.visible
                                                    loops: Animation.Infinite
                                                    alwaysRunToEnd: true
                                                    NumberAnimation { to: 1.25; duration: 1600; easing.type: Easing.InOutSine }
                                                    NumberAnimation { to: 1.0;  duration: 1600; easing.type: Easing.InOutSine }
                                                }
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                text: dayNum
                                                color: isToday ? theme.crust : (isCurrentMonth ? theme.text : theme.surface1)
                                                font.family: "JetBrains Mono"
                                                font.weight: isToday ? Font.Bold : Font.Normal
                                                font.pixelSize: s(11)
                                            }
                                            MouseArea { id: dayMa; anchors.fill: parent; hoverEnabled: true }
                                        }
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: s(4)
                            spacing: s(6)

                            Repeater {
                                model: [
                                    { icon: "󰥔", label: "Timer", target: "focustime" }
                                ]
                                delegate: Rectangle {
                                    id: launchBtn
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: s(34)
                                    radius: s(10)
                                    color: launchMa.containsMouse ? theme.surface1 : "transparent"
                                    Behavior on color { ColorAnimation { duration: root.tBase } }
                                    scale: launchMa.pressed ? 0.94 : (launchMa.containsMouse ? 1.03 : 1.0)
                                    Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: s(6)
                                        Text { text: modelData.icon; font.family: "Iosevka Nerd Font"; font.pixelSize: s(13); color: launchMa.containsMouse ? theme.mauve : theme.text; Behavior on color { ColorAnimation { duration: root.tBase } } }
                                        Text { text: modelData.label; color: theme.text; font.family: "JetBrains Mono"; font.pixelSize: s(11) }
                                    }
                                    MouseArea {
                                        id: launchMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle " + modelData.target])
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
