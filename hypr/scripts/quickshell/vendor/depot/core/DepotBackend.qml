pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Every command Depot runs goes through here. The UI reads these properties
// and calls the functions; it never starts a process itself.
Singleton {
    id: root

    readonly property string script: DepotStore.localPath(Qt.resolvedUrl("../scripts/depot.sh"))

    property var info: ({ backend: "", aurHelper: "", polkitAgent: true, pkexec: true, curl: true, supported: true })
    property bool detected: false

    property var featured: []
    property bool featuredLoaded: false
    property bool featuredPending: false

    property string query: ""
    property var results: []
    property string resultsQuery: ""
    property bool searchPending: false
    // Old results stay on screen until the new query's results replace them.
    readonly property bool searching: root.query !== "" && root.resultsQuery !== root.query

    property string busyPackage: ""
    property string busyAction: ""
    property string busyName: ""
    readonly property bool busy: root.busyPackage !== ""

    // {action, package, name, ok, code, reason, msg}
    property var lastResult: null

    // Encoded by hand: in Qt 6 Qt.btoa(string) converts its input to UTF-8
    // itself, so UTF-8 bytes handed to it come out encoded twice.
    function b64(str) {
        const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        const encoded = encodeURIComponent(String(str));
        const bytes = [];
        for (let i = 0; i < encoded.length; i++) {
            if (encoded[i] === "%") {
                bytes.push(parseInt(encoded.substr(i + 1, 2), 16));
                i += 2;
            } else {
                bytes.push(encoded.charCodeAt(i));
            }
        }
        let out = "";
        for (let i = 0; i < bytes.length; i += 3) {
            const chunk = (bytes[i] << 16) | ((bytes[i + 1] || 0) << 8) | (bytes[i + 2] || 0);
            out += alphabet[(chunk >> 18) & 63] + alphabet[(chunk >> 12) & 63];
            out += i + 1 < bytes.length ? alphabet[(chunk >> 6) & 63] : "=";
            out += i + 2 < bytes.length ? alphabet[chunk & 63] : "=";
        }
        return out;
    }

    function parseJson(text, fallback) {
        try {
            return JSON.parse(String(text || "").trim());
        } catch (e) {
            return fallback;
        }
    }

    function refresh() {
        detectProc.running = true;
        root.loadFeatured();
    }

    function loadFeatured() {
        if (featuredProc.running) {
            root.featuredPending = true;
            return;
        }
        featuredProc.running = true;
    }

    function search(text) {
        root.query = String(text || "").trim();
        if (root.query === "") {
            searchDebounce.stop();
            root.results = [];
            root.resultsQuery = "";
            return;
        }
        searchDebounce.restart();
    }

    function startSearch() {
        if (root.query === "") return;
        if (searchProc.running) {
            root.searchPending = true;
            return;
        }
        root.searchPending = false;
        searchProc.requestedQuery = root.query;
        searchProc.command = ["bash", root.script, "search", root.b64(root.query)];
        searchProc.running = true;
    }

    function install(packageName, source, name) {
        return root.run("install", packageName, source === "aur" ? "aur" : "repo", name);
    }

    function remove(packageName, name) {
        return root.run("remove", packageName, "", name);
    }

    function run(action, packageName, source, name) {
        if (root.busy || !packageName) return false;
        root.busyPackage = packageName;
        root.busyAction = action;
        root.busyName = name || packageName;
        let command = ["bash", root.script, action, root.b64(packageName)];
        if (source) command.push(source);
        actionProc.command = command;
        actionProc.running = true;
        return true;
    }

    function dismissResult() {
        root.lastResult = null;
    }

    Process {
        id: detectProc
        running: true
        command: ["bash", root.script, "detect"]
        stdout: StdioCollector {
            onStreamFinished: {
                let parsed = root.parseJson(this.text, null);
                if (parsed && typeof parsed === "object") root.info = parsed;
                root.detected = true;
            }
        }
    }

    Process {
        id: featuredProc
        running: true
        command: ["bash", root.script, "featured"]
        stdout: StdioCollector {
            onStreamFinished: {
                let parsed = root.parseJson(this.text, []);
                root.featured = Array.isArray(parsed) ? parsed : [];
                root.featuredLoaded = true;
            }
        }
        onRunningChanged: {
            if (running || !root.featuredPending) return;
            root.featuredPending = false;
            Qt.callLater(root.loadFeatured);
        }
    }

    Timer {
        id: searchDebounce
        interval: 350
        onTriggered: root.startSearch()
    }

    Process {
        id: searchProc
        property string requestedQuery: ""
        stdout: StdioCollector {
            onStreamFinished: {
                // A reply for a query the user has already typed past is dropped.
                if (searchProc.requestedQuery !== root.query) return;
                let parsed = root.parseJson(this.text, []);
                root.results = Array.isArray(parsed) ? parsed : [];
                root.resultsQuery = searchProc.requestedQuery;
            }
        }
        onRunningChanged: {
            if (running) return;
            if (root.searchPending || (root.query !== "" && root.resultsQuery !== root.query))
                Qt.callLater(root.startSearch);
        }
    }

    Process {
        id: actionProc
        stdout: StdioCollector {
            onStreamFinished: {
                let parsed = root.parseJson(this.text, null);
                if (!parsed || typeof parsed !== "object")
                    parsed = { ok: false, code: -1, reason: "failed", msg: String(this.text || "").trim() };
                root.lastResult = {
                    action: root.busyAction,
                    package: root.busyPackage,
                    name: root.busyName,
                    ok: parsed.ok === true,
                    code: parsed.code,
                    reason: parsed.reason || "",
                    msg: parsed.msg || ""
                };
                root.busyPackage = "";
                root.busyAction = "";
                root.busyName = "";
                // Installed flags changed on disk; both lists re-read them.
                root.loadFeatured();
                if (root.query !== "") root.startSearch();
            }
        }
    }
}
