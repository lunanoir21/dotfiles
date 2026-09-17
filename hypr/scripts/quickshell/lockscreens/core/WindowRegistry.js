.pragma library

function getScale(mw, mh, userScale) {
    if (arguments.length === 2) {
        userScale = mh;
        mh = mw * (1080.0 / 1920.0);
    }

    if (mw <= 0 || mh <= 0) return 1.0;
    
    let rw = mw / 1920.0;
    let rh = mh / 1080.0;
    let r = Math.min(rw, rh);
    
    let baseScale = 1.0;
    
    if (r <= 1.0) {
        baseScale = Math.max(0.35, Math.pow(r, 0.85));
    } else {
        baseScale = Math.pow(r, 0.5);
    }
    
    return baseScale * (userScale !== undefined ? userScale : 1.0);
}

function s(val, scale) {
    return Math.round(val * scale);
}

function getLayout(name, mx, my, mw, mh, userScale) {
    let scale = getScale(mw, mh, userScale);
    const settingsW = Math.min(s(1320, scale), Math.max(s(760, scale), mw - s(48, scale)));
    const settingsH = Math.min(s(820, scale), Math.max(s(560, scale), mh - s(88, scale)));

    let base = {
        // --- Top Right Popups ---
        "sidebarcenter": { w: s(440, scale), h: mh - s(16, scale), rx: mw - s(448, scale), ry: s(8, scale), comp: "widgets/sidebar-center/SidebarCenter.qml" },
        
        // --- Central Standard Tools ---
        "applauncher": { w: s(800, scale), h: s(700, scale), rx: Math.floor((mw/2)-(s(800, scale)/2)), ry: Math.floor((mh/2)-(s(700, scale)/2)), comp: "widgets/applauncher/appLauncher.qml" },
        "clipboard": { w: s(800, scale), h: s(700, scale), rx: Math.floor((mw/2)-(s(800, scale)/2)), ry: Math.floor((mh/2)-(s(700, scale)/2)), comp: "widgets/clipboard/ClipboardManager.qml" },
        "processes": { w: s(820, scale), h: s(650, scale), rx: Math.floor((mw/2)-(s(820, scale)/2)), ry: Math.floor((mh/2)-(s(650, scale)/2)), comp: "widgets/processes/ProcessMonitor.qml" },
        // Ses karistirici: uygulama basina dikey ekolayzer surguleri.
        "mixer": { w: s(900, scale), h: s(540, scale), rx: Math.floor((mw/2)-(s(900, scale)/2)), ry: Math.floor((mh/2)-(s(540, scale)/2)), comp: "widgets/mixer/VolumeMixer.qml" },
        // Kilit ekranı seçici: hangi lockscreens/NN-*.qml aktif olacağını seçer.
        "lockscreen": { w: s(980, scale), h: s(560, scale), rx: Math.floor((mw/2)-(s(980, scale)/2)), ry: Math.floor((mh/2)-(s(560, scale)/2)), comp: "widgets/lockscreen/LockscreenPicker.qml" },

        // --- Central Large Tools ---

        // --- Extralarge / Custom Centered ---
        "workspaces": { w: s(1540, scale), h: s(390, scale), rx: Math.floor((mw/2)-(s(1540, scale)/2)), ry: s(125, scale), comp: "widgets/workspaces/WorkspaceOverview.qml" },
        "wallpaper": { w: mw, h: s(650, scale), rx: 0, ry: Math.floor((mh/2)-(s(650, scale)/2)), comp: "widgets/wallpaper/WallpaperPicker.qml" },

        // --- Centered Settings Window ---
        // Ayarlar sol kenara yapışan panel değil, ortalanmış bir pencere.
        // Küçük ekranlarda pencerenin dışarı taşmaması için genişlik/yükseklik
        // ekranın güvenli alanına göre sınırlandırılıyor.
        "settings":  { w: settingsW, h: settingsH, rx: Math.floor((mw/2)-(settingsW/2)), ry: Math.floor((mh/2)-(settingsH/2)), comp: "widgets/settings/SettingsWindow.qml" },
        
        // --- Utility ---
        "hidden":    { w: 1, h: 1, rx: -5000 - mx, ry: -5000 - my, comp: "" } 
    };

    if (!base[name]) return null;
    
    let t = base[name];
    t.x = mx + t.rx;
    t.y = my + t.ry;
    
    return t;
}

function getPopupLayout(mw, mh, userScale) {
    if (arguments.length === 2) {
        userScale = mh;
        mh = mw * (1080.0 / 1920.0);
    }
    
    let scale = getScale(mw, mh, userScale);
    return {
        w: s(350, scale),
        marginTop: s(60, scale),
        marginRight: s(20, scale),
        spacing: s(12, scale),
        radius: s(14, scale),
        padding: s(12, scale)
    };
}
