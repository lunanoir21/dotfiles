import QtQuick
import "../../../core"

// Aranabilir ayar kataloğu.
//
// Buradaki her girdi hem arama sonuçlarında CANLI bir kontrol olarak çizilir
// hem de kullanıcıyı ait olduğu sayfaya götürebilir. Amaç şu: kullanıcı bir
// ayarın hangi kategoride olduğunu bilmek zorunda kalmasın — adını (ya da
// yakın bir kelimeyi) yazsın, kontrolü orada, o an çevirsin.
//
// Katalog yalnızca "tek değerli" ayarları taşır. Kısayollar, monitör düzeni,
// ağ/bluetooth cihazları gibi kendi ekranını hak eden şeyler `pageHints`
// üzerinden aranır ve sonuç kullanıcıyı sayfaya götürür.
Item {
    id: index

    // keywords: etiketin kendisinde geçmeyen ama insanların arayacağı kelimeler.
    // Türkçe/İngilizce ve Hyprland'in kendi terimleri bilerek karışık.
    readonly property var entries: [
        // ---- GÖRÜNÜM · PENCERE ----
        { id: "gapsIn", page: "appearance", card: "Pencere", type: "slider",
          label: "İç boşluk", hint: "Pencereler arasındaki mesafe",
          prop: "hyprGapsIn", hyprKey: "gapsIn", live: true, apply: "hypr",
          min: 0, max: 40, step: 1, decimals: 0,
          keywords: ["gaps in", "aralık", "margin", "pencere arası"] },

        { id: "gapsOut", page: "appearance", card: "Pencere", type: "slider",
          label: "Dış boşluk", hint: "Ekran kenarı ile pencereler arasındaki mesafe",
          prop: "hyprGapsOut", hyprKey: "gapsOut", live: true, apply: "hypr",
          min: 0, max: 60, step: 1, decimals: 0,
          keywords: ["gaps out", "kenar", "margin", "ekran kenarı"] },

        { id: "floatGaps", page: "appearance", card: "Pencere", type: "slider",
          label: "Yüzen pencere boşluğu", hint: "float_gaps",
          prop: "hyprFloatGaps", hyprKey: "floatGaps", live: true, apply: "hypr",
          min: 0, max: 40, step: 1, decimals: 0,
          keywords: ["float", "yüzen", "floating"] },

        { id: "borderSize", page: "appearance", card: "Pencere", type: "spin",
          label: "Kenarlık kalınlığı", hint: "border_size",
          prop: "hyprBorderSize", hyprKey: "borderSize", live: true, apply: "hypr",
          min: 0, max: 10, step: 1,
          keywords: ["border", "çerçeve", "kenarlik", "outline"] },

        { id: "resizeOnBorder", page: "appearance", card: "Pencere", type: "toggle",
          label: "Kenardan boyutlandır", hint: "Pencere kenarına tıklayıp sürükleyerek boyutlandırma",
          prop: "hyprResizeOnBorder", hyprKey: "resizeOnBorder", live: true, apply: "hypr",
          keywords: ["resize", "boyut", "sürükle"] },

        // ---- GÖRÜNÜM · DEKORASYON ----
        { id: "rounding", page: "appearance", card: "Dekorasyon", type: "slider",
          label: "Köşe yuvarlaklığı", hint: "rounding",
          prop: "hyprRounding", hyprKey: "rounding", live: true, apply: "hypr",
          min: 0, max: 30, step: 1, decimals: 0,
          keywords: ["radius", "corner", "köşe", "yuvarlak", "oval"] },

        { id: "activeOpacity", page: "appearance", card: "Dekorasyon", type: "slider",
          label: "Aktif pencere saydamlığı", hint: "Odaktaki pencerenin opaklığı",
          prop: "hyprActiveOpacity", hyprKey: "activeOpacity", live: true, apply: "hypr",
          min: 0.3, max: 1.0, step: 0.01, decimals: 2,
          keywords: ["opacity", "saydam", "şeffaf", "transparan", "alpha"] },

        { id: "inactiveOpacity", page: "appearance", card: "Dekorasyon", type: "slider",
          label: "Pasif pencere saydamlığı", hint: "Odakta olmayan pencerelerin opaklığı",
          prop: "hyprInactiveOpacity", hyprKey: "inactiveOpacity", live: true, apply: "hypr",
          min: 0.3, max: 1.0, step: 0.01, decimals: 2,
          keywords: ["opacity", "saydam", "şeffaf", "transparan", "alpha", "arka plan"] },

        { id: "blurEnabled", page: "appearance", card: "Dekorasyon", type: "toggle",
          label: "Bulanıklık", hint: "Saydam pencerelerin arkasını bulanıklaştır",
          prop: "hyprBlurEnabled", hyprKey: "blurEnabled", live: true, apply: "hypr",
          keywords: ["blur", "buğu", "cam", "frosted"] },

        { id: "blurSize", page: "appearance", card: "Dekorasyon", type: "slider",
          label: "Bulanıklık yarıçapı", hint: "blur size",
          prop: "hyprBlurSize", hyprKey: "blurSize", live: true, apply: "hypr",
          min: 1, max: 30, step: 1, decimals: 0,
          keywords: ["blur", "buğu", "yarıçap"] },

        { id: "blurPasses", page: "appearance", card: "Dekorasyon", type: "spin",
          label: "Bulanıklık geçişi", hint: "Daha fazla geçiş = daha yumuşak, daha pahalı",
          prop: "hyprBlurPasses", hyprKey: "blurPasses", live: true, apply: "hypr",
          min: 1, max: 6, step: 1,
          keywords: ["blur", "passes", "geçiş", "kalite"] },

        { id: "shadowEnabled", page: "appearance", card: "Dekorasyon", type: "toggle",
          label: "Gölge", hint: "Pencerelerin altındaki gölge",
          prop: "hyprShadowEnabled", hyprKey: "shadowEnabled", live: true, apply: "hypr",
          keywords: ["shadow", "gölge", "drop shadow"] },

        // ---- GÖRÜNÜM · GİRDİ ----
        { id: "sensitivity", page: "appearance", card: "Girdi", type: "slider",
          label: "İmleç hassasiyeti", hint: "Fare hızı (-1 en yavaş, 1 en hızlı)",
          prop: "hyprSensitivity", hyprKey: "sensitivity", live: true, apply: "hypr",
          min: -1.0, max: 1.0, step: 0.05, decimals: 2,
          keywords: ["mouse", "fare", "imleç", "hız", "sensitivity", "dpi", "pointer"] },

        { id: "naturalScroll", page: "appearance", card: "Girdi", type: "toggle",
          label: "Doğal kaydırma", hint: "Kaydırma yönünü ters çevirir",
          prop: "hyprNaturalScroll", hyprKey: "naturalScroll", live: true, apply: "hypr",
          keywords: ["scroll", "kaydırma", "touchpad", "dokunmatik", "ters"] },

        // ---- GÖRÜNÜM · YAZI TİPİ & ANİMASYON ----
        { id: "fontFamily", page: "appearance", card: "Yazı tipi & animasyon", type: "text",
          label: "Yazı tipi", hint: "Hyprland arayüz yazı tipi",
          prop: "hyprFontFamily", hyprKey: "fontFamily", live: true, apply: "hypr",
          placeholder: "JetBrains Mono",
          keywords: ["font", "yazı", "tipografi", "typeface"] },

        { id: "animationsEnabled", page: "appearance", card: "Yazı tipi & animasyon", type: "toggle",
          label: "Animasyonlar", hint: "Pencere geçiş animasyonları",
          prop: "hyprAnimationsEnabled", hyprKey: "animationsEnabled", live: true, apply: "hypr",
          keywords: ["animation", "animasyon", "hareket", "geçiş", "motion"] },

        { id: "animSpeed", page: "appearance", card: "Yazı tipi & animasyon", type: "slider",
          label: "Animasyon süresi", hint: "Küçük değer = daha hızlı",
          prop: "hyprAnimSpeed", hyprKey: "animSpeed", live: false, apply: "hypr",
          min: 1, max: 20, step: 1, decimals: 0,
          keywords: ["animation", "animasyon", "hız", "süre", "speed"] },

        // ---- GENEL ----
        { id: "uiScale", page: "general", card: "Arayüz", type: "slider",
          label: "Arayüz ölçeği", hint: "Tüm quickshell widget'larının boyutu",
          prop: "uiScale", apply: "app",
          min: 0.5, max: 2.0, step: 0.05, decimals: 2,
          keywords: ["scale", "ölçek", "boyut", "zoom", "büyüklük", "dpi", "widget"] },

        { id: "workspaceCount", page: "general", card: "Arayüz", type: "spin",
          label: "Çalışma alanı sayısı", hint: "Değişiklikte üst bar yeniden yüklenir",
          prop: "workspaceCount", apply: "app",
          min: 2, max: 10, step: 1,
          keywords: ["workspace", "çalışma alanı", "masaüstü", "desktop", "sayı"] },

        { id: "language", page: "general", card: "Klavye", type: "text",
          label: "Klavye düzeni", hint: "Virgülle birden fazla: us,tr",
          prop: "language", apply: "app", placeholder: "us",
          keywords: ["keyboard", "klavye", "layout", "düzen", "dil", "türkçe", "language"] },

        { id: "kbOptions", page: "general", card: "Klavye", type: "text",
          label: "Klavye seçenekleri", hint: "kb_options — örn. grp:alt_shift_toggle",
          prop: "kbOptions", apply: "app", placeholder: "grp:alt_shift_toggle",
          keywords: ["keyboard", "klavye", "options", "kısayol", "dil değiştir"] },

        { id: "wallpaperDir", page: "general", card: "Duvar kağıdı", type: "text",
          label: "Duvar kağıdı klasörü", hint: "Duvar kağıdı seçicinin taradığı dizin",
          prop: "wallpaperDir", apply: "app", placeholder: "~/Pictures/Wallpapers",
          keywords: ["wallpaper", "duvar kağıdı", "arka plan", "background", "klasör", "dizin"] },

        // ---- HAVA ----
        { id: "weatherApiKey", page: "weather", card: "OpenWeather", type: "text",
          label: "API anahtarı", hint: "openweathermap.org üzerinden ücretsiz alınır",
          prop: "weatherApiKey", apply: "app", placeholder: "32 karakterlik anahtar",
          keywords: ["weather", "hava", "api", "anahtar", "openweather", "key"] },

        { id: "weatherCityId", page: "weather", card: "OpenWeather", type: "text",
          label: "Şehir ID", hint: "OpenWeather'ın sayısal şehir kimliği",
          prop: "weatherCityId", apply: "app", placeholder: "745044",
          keywords: ["weather", "hava", "şehir", "city", "konum", "location"] },

        { id: "weatherUnit", page: "weather", card: "OpenWeather", type: "select",
          label: "Sıcaklık birimi", hint: "Hava durumu widget'ının gösterdiği birim",
          prop: "weatherUnit", apply: "app",
          options: [ { value: "metric", label: "Celsius (°C)" },
                     { value: "imperial", label: "Fahrenheit (°F)" } ],
          keywords: ["celsius", "fahrenheit", "sıcaklık", "birim", "derece", "unit"] }
    ]

    // Kendi ekranı olan, tek bir değere indirgenemeyen alanlar. Arama bunları
    // da bulur ama sonuç bir kontrol değil, sayfaya giden bir kart olur.
    readonly property var pageHints: [
        { page: "network",   icon: "󰤨", label: "Ağ",
          hint: "Wi-Fi ağları, Ethernet ve VPN bağlantıları",
          keywords: ["wifi", "wi-fi", "ağ", "network", "internet", "ethernet", "kablo", "vpn", "ssid", "şifre", "parola", "bağlan", "kablosuz",
                     "internet yok", "bağlantı", "ip adresi", "dns", "ağı unut", "wifi şifresi"] },
        { page: "bluetooth", icon: "󰂯", label: "Bluetooth",
          hint: "Cihaz eşleştirme ve bağlantı yönetimi",
          keywords: ["bluetooth", "bt", "kulaklık", "headphone", "eşleştir", "pair", "hoparlör", "mouse", "klavye", "cihaz",
                     "airpods", "bağlanmıyor", "cihaz ekle", "kulaklık bağla"] },
        { page: "audio",     icon: "󰕾", label: "Ses",
          hint: "Çıkış ve giriş cihazları, seviyeler",
          keywords: ["ses", "audio", "sound", "hoparlör", "speaker", "mikrofon", "microphone", "volume", "seviye", "kulaklık", "çıkış", "giriş",
                     "ses gelmiyor", "ses yok", "hdmi ses", "sustur", "varsayılan cihaz"] },
        { page: "power",     icon: "󰁹", label: "Güç & pil",
          hint: "Pil durumu, güç profili ve uyku davranışı",
          keywords: ["pil", "battery", "güç", "power", "uyku", "sleep", "suspend", "şarj", "profil", "performans", "tasarruf", "kilit", "lock",
                     "ekran kapansın", "ekran kapanma", "otomatik kilit", "ekran süresi", "bekleme", "zaman aşımı", "pil sağlığı"] },
        { page: "keybinds",  icon: "󰌌", label: "Kısayollar",
          hint: "Klavye kısayollarını görüntüle ve düzenle",
          keywords: ["kısayol", "shortcut", "keybind", "tuş", "hotkey", "bind", "super", "mod", "tuş atama", "kısayol değiştir"] },
        { page: "monitors",  icon: "󰍹", label: "Monitörler",
          hint: "Ekran düzeni, çözünürlük, yenileme hızı ve ölçek",
          keywords: ["monitör", "monitor", "ekran", "display", "çözünürlük", "resolution", "hz", "yenileme", "refresh", "ölçek", "scale", "düzen",
                     "ikinci ekran", "harici ekran", "projeksiyon", "ekran düzeni", "dikey", "çevir"] },
        { page: "appearance", icon: "󰸌", label: "Tema",
          hint: "Renk teması — saf siyah, gri, saf beyaz, ten rengi",
          keywords: ["tema", "theme", "renk", "color", "siyah", "beyaz", "gri", "ten rengi", "bej",
                     "açık tema", "koyu tema", "dark", "light", "palet", "görünüm değiştir"] },
        { page: "startup",   icon: "󰅐", label: "Başlangıç",
          hint: "Oturum açılışında çalışan komutlar",
          keywords: ["başlangıç", "startup", "autostart", "otomatik", "açılış", "exec", "boot"] },
        { page: "widgets",   icon: "󰕮", label: "Widget'lar",
          hint: "Top Bar, Quay, Dynamic Island ve diğer sistem yüzeyleri",
          keywords: ["widget", "widgets", "yüzey", "top bar", "quay", "dock", "başlatıcı", "launcher", "sabitle", "pin", "klasör", "dynamic island", "island", "sidebar", "launcher", "clipboard", "mixer", "süreçler", "workspace", "duvar kağıdı"] },

        // Dynamic Island'ın kendi menüsündeki bölümler. "island:" öneki
        // SettingsWindow.goPage() tarafından yakalanıp adaya yönlendiriliyor;
        // arama sonucundan tek tıkla doğru bölüm açılıyor.
        { page: "island:notifications", icon: "󰂚", label: "Bildirimler",
          hint: "Dynamic Island › kart süresi ve içeriği",
          keywords: ["bildirim", "notification", "uyarı", "kart", "süre", "popup", "ada"] },
        { page: "island:media", icon: "󰎈", label: "Oynatıcı",
          hint: "Dynamic Island › görsel öğeler, spektrum, sözler",
          keywords: ["müzik", "media", "oynatıcı", "player", "spektrum", "şarkı", "sözler", "lyrics", "albüm", "ada"] },
        { page: "island:clock", icon: "󰥔", label: "Saat",
          hint: "Dynamic Island › biçim ve çizim stili",
          keywords: ["saat", "clock", "zaman", "time", "tarih", "biçim", "format", "ada"] },
        { page: "island:timetools", icon: "󰔛", label: "Zaman araçları",
          hint: "Dynamic Island › zamanlayıcı, kronometre, odak, alarm",
          keywords: ["zamanlayıcı", "timer", "kronometre", "stopwatch", "alarm", "odak", "focus", "pomodoro", "ada"] },
        { page: "island:calls", icon: "󰏥", label: "Aramalar",
          hint: "Dynamic Island › gelen arama davranışı",
          keywords: ["arama", "call", "telefon", "gelen arama", "ada"] },
        { page: "island:panels", icon: "󰕮", label: "Ada panelleri",
          hint: "Dynamic Island › çiplerin açtığı ek paneller",
          keywords: ["panel", "çip", "chip", "şerit", "ada", "island"] },
        { page: "island:appearance", icon: "󰏘", label: "Ada görünümü",
          hint: "Dynamic Island › renkler ve yüzeyler",
          keywords: ["ada", "island", "renk", "tema", "yüzey", "görünüm"] }
    ]

    // ------------------------------------------------------------------
    // Arama
    // ------------------------------------------------------------------
    // Türkçe arama için normalize: aksan kaldır + küçült. Kullanıcı "boslugu"
    // yazınca da "boşluğu" bulunsun; klavye düzeni ne olursa olsun çalışsın.
    function norm(str) {
        return String(str)
            .toLocaleLowerCase("tr")
            .replace(/ı/g, "i").replace(/İ/g, "i")
            .replace(/ş/g, "s").replace(/ğ/g, "g").replace(/ü/g, "u")
            .replace(/ö/g, "o").replace(/ç/g, "c")
            // Son ünsüz yumuşaması: "boşluğu" yazan da "boşluk"u bulsun.
            // Her iki tarafa da uygulandığı için eşleşmeyi bozmaz.
            .replace(/g\b/g, "k")
            .trim();
    }

    // Girdiyi tek bir aranabilir metne indirger.
    function haystack(e) {
        return index.norm([e.label, e.hint || "", e.card || "", (e.keywords || []).join(" ")].join(" "));
    }

    // Puanlama: etiket başlangıcı > etiket içi > anahtar kelime > ipucu.
    // Sıralamanın amacı ilk sonucun neredeyse her zaman doğru olması.
    function rawScore(e, q) {
        const label = index.norm(e.label);
        const hay = index.haystack(e);
        if (!hay.includes(q)) return 0;
        if (label === q) return 100;
        if (label.startsWith(q)) return 80;
        if (label.includes(q)) return 60;
        if (index.norm((e.keywords || []).join(" ")).includes(q)) return 40;
        return 20;
    }

    // Tam eşleşme yoksa Türkçe ekleri kırpıp kökü deniyoruz: "animasyonu"
    // yazan "Animasyonlar"ı, "köşeleri" yazan "Köşe yuvarlaklığı"nı bulsun.
    //
    // Kök eşleşmesi de aynı puanlamadan geçiyor, sadece bir kademe altta:
    // düz bir "bulundu" puanı verilseydi kökü içeren her kayıt eşitlenir ve
    // sıralama rastgeleleşirdi (kart adı "Yazı tipi & animasyon" olduğu için
    // yazı tipi ayarı animasyon ayarının önüne geçiyordu).
    function score(e, q) {
        const direct = index.rawScore(e, q);
        if (direct > 0) return direct;
        if (q.length < 5) return 0;
        for (let cut = 1; cut <= 4; cut++) {
            const stem = q.slice(0, q.length - cut);
            if (stem.length < 4) break;
            const sc = index.rawScore(e, stem);
            if (sc > 0) return Math.max(5, sc - 30);
        }
        return 0;
    }

    // Boşlukla ayrılmış her parça ayrı ayrı eşleşmeli ("koşe yuvarlak" gibi).
    function matches(e, terms) {
        let total = 0;
        for (let i = 0; i < terms.length; i++) {
            const sc = index.score(e, terms[i]);
            if (sc === 0) return 0;
            total += sc;
        }
        return total;
    }

    function search(query) {
        const q = index.norm(query);
        if (q === "") return [];
        const terms = q.split(/\s+/).filter(t => t.length > 0);

        let out = [];
        for (let i = 0; i < index.entries.length; i++) {
            const sc = index.matches(index.entries[i], terms);
            if (sc > 0) out.push({ kind: "setting", score: sc, entry: index.entries[i] });
        }
        for (let i = 0; i < index.pageHints.length; i++) {
            const sc = index.matches(index.pageHints[i], terms);
            // Sayfa kartları hafif geri çekiliyor: kullanıcı doğrudan
            // çevirebileceği bir kontrol varsa o önce gelsin.
            if (sc > 0) out.push({ kind: "page", score: sc - 5, hint: index.pageHints[i] });
        }
        out.sort((a, b) => b.score - a.score);
        return out;
    }

    // ------------------------------------------------------------------
    // Uygulama
    // ------------------------------------------------------------------
    // Arama sonucundan yapılan değişiklik de sayfadakiyle aynı yolu izler:
    // hypr ayarları anında önizlenip debounce ile diske yazılır, uygulama
    // ayarları kısa bir gecikmeyle settings.json'a düşer.
    signal applied(string id)

    Timer {
        id: appSaveDebounce
        interval: 600
        onTriggered: {
            Config.saveAppSettings();
            index.applied("");
        }
    }

    function currentValue(entry) {
        return Config[entry.prop];
    }

    function apply(entry, value) {
        Config[entry.prop] = value;
        if (entry.apply === "hypr") {
            if (entry.live) Config.previewHyprSetting(entry.hyprKey, value);
            Config.queueHyprSave();
        } else {
            appSaveDebounce.restart();
        }
        index.applied(entry.id);
    }
}
