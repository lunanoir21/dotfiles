pragma Singleton

import QtQuick
import Quickshell

// Mock catalog for the UI pass: screenshots, developer, license and version
// history that the real AppStream/Flathub backend will supply later. Nothing
// here runs a process; DepotBackend.featured stays the source for install
// state. Remove this file once the C++ plugin lands.
Singleton {
    id: root

    readonly property var byId: ({
        firefox: { developer: "Mozilla", license: "MPL-2.0", flatpakId: "org.mozilla.firefox",
            tags: ["internet", "network"], shots: 3 },
        chromium: { developer: "The Chromium Authors", license: "BSD-3-Clause", flatpakId: "org.chromium.Chromium",
            tags: ["internet", "network"], shots: 2 },
        brave: { developer: "Brave Software", license: "MPL-2.0", flatpakId: "com.brave.Browser",
            tags: ["internet", "network"], shots: 2 },
        qbittorrent: { developer: "The qBittorrent project", license: "GPL-2.0", flatpakId: "org.qbittorrent.qBittorrent",
            tags: ["internet", "filesharing"], shots: 2 },
        telegram: { developer: "Telegram FZ-LLC", license: "GPL-3.0", flatpakId: "org.telegram.desktop",
            tags: ["communication", "chat"], shots: 3 },
        discord: { developer: "Discord Inc.", license: "Proprietary", flatpakId: "com.discordapp.Discord",
            tags: ["communication", "chat"], shots: 3 },
        thunderbird: { developer: "Mozilla", license: "MPL-2.0", flatpakId: "org.mozilla.Thunderbird",
            tags: ["communication", "email"], shots: 2 },
        libreoffice: { developer: "The Document Foundation", license: "MPL-2.0", flatpakId: "org.libreoffice.LibreOffice",
            tags: ["office", "productivity"], shots: 4 },
        obsidian: { developer: "Obsidian.md", license: "Proprietary", flatpakId: "md.obsidian.Obsidian",
            tags: ["office", "notes"], shots: 3 },
        okular: { developer: "KDE", license: "GPL-2.0", flatpakId: "org.kde.okular",
            tags: ["office", "viewer"], shots: 2 },
        vscode: { developer: "Microsoft", license: "MIT", flatpakId: "com.visualstudio.code",
            tags: ["development", "ide"], shots: 3 },
        zed: { developer: "Zed Industries", license: "GPL-3.0", flatpakId: "dev.zed.Zed",
            tags: ["development", "ide"], shots: 2 },
        neovim: { developer: "Neovim contributors", license: "Apache-2.0", flatpakId: "",
            tags: ["development", "editor"], shots: 1 },
        vlc: { developer: "VideoLAN", license: "GPL-2.0", flatpakId: "org.videolan.VLC",
            tags: ["media", "video"], shots: 2 },
        obs: { developer: "OBS Project", license: "GPL-2.0", flatpakId: "com.obsproject.Studio",
            tags: ["media", "video", "streaming"], shots: 3 },
        gimp: { developer: "The GIMP Team", license: "GPL-3.0", flatpakId: "org.gimp.GIMP",
            tags: ["media", "graphics"], shots: 4 },
        spotify: { developer: "Spotify AB", license: "Proprietary", flatpakId: "com.spotify.Client",
            tags: ["media", "music"], shots: 2 },
        btop: { developer: "aristocratos", license: "Apache-2.0", flatpakId: "",
            tags: ["system", "monitor"], shots: 1 },
        timeshift: { developer: "Tony George", license: "GPL-3.0", flatpakId: "",
            tags: ["system", "backup"], shots: 1 },
        flameshot: { developer: "Flameshot org", license: "GPL-3.0", flatpakId: "org.flameshot.Flameshot",
            tags: ["system", "graphics"], shots: 2 },
        gparted: { developer: "GParted team", license: "GPL-2.0", flatpakId: "",
            tags: ["system", "utility"], shots: 1 }
    })

    readonly property var editorsPicks: ["firefox", "obsidian", "zed", "obs"]
    readonly property var popularWeek: ["discord", "spotify", "vscode", "vlc", "telegram", "gimp"]
    readonly property var newAndUpdated: ["zed", "brave", "flameshot", "okular", "btop"]

    function detailFor(id) {
        return root.byId[id] || { developer: "", license: "", flatpakId: "", tags: [], shots: 1 };
    }

    // Deterministic-looking mock SHAs/dates so the version history list has
    // something to show without a real Flathub/pacman log query yet.
    function historyFor(id) {
        let seed = 0;
        for (let i = 0; i < id.length; i++) seed = (seed * 31 + id.charCodeAt(i)) >>> 0;
        let out = [];
        let days = 6;
        for (let i = 0; i < 3; i++) {
            let sha = (seed >>> (i * 4)).toString(16).padStart(7, "0").slice(0, 7);
            let d = new Date(2026, 8 - i * 2, Math.max(1, 27 - i * days - (seed % 5)));
            out.push({
                version: i === 0 ? "current" : "v" + (10 - i) + "." + ((seed + i) % 9),
                date: d.toISOString().slice(0, 10),
                sha: sha,
                notes: i === 0 ? "" : ""
            });
        }
        return out;
    }

    function sourcesFor(entry) {
        let out = [];
        let detail = root.detailFor(entry.id);
        if (detail.flatpakId) out.push({ id: "flathub", label: "Flathub", packageName: detail.flatpakId });
        let packages = entry.packages || {};
        if (packages.pacman) out.push({ id: "pacman", label: "pacman", packageName: packages.pacman });
        if (packages.apt) out.push({ id: "apt", label: "apt", packageName: packages.apt });
        if (packages.dnf) out.push({ id: "dnf", label: "dnf", packageName: packages.dnf });
        if (packages.aur) out.push({ id: "aur", label: "AUR", packageName: packages.aur });
        return out;
    }
}
