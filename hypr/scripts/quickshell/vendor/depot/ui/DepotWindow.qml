pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../core"

// A plain toplevel window, not a layer-shell surface, so it opens the same way
// on GNOME, KDE, Hyprland or any other desktop.
FloatingWindow {
    id: root

    title: "Depot"
    implicitWidth: 1040
    implicitHeight: 720
    minimumSize: Qt.size(640, 480)
    color: DepotTheme.base

    property string tab: "explore"           // explore | categories | installed | updates | settings
    property var openEntry: null             // set to view an app's detail page
    property string armedPackage: ""
    readonly property bool searching: DepotBackend.query !== ""

    function focusSearch() {
        search.focusInput();
    }

    function setQuery(text) {
        root.openEntry = null;
        search.text = text;
        search.focusInput();
        stage.reveal();
    }

    function goTab(tabId) {
        root.openEntry = null;
        root.tab = tabId;
        search.text = "";
        stage.reveal();
    }

    function openApp(entry) {
        root.openEntry = entry;
        stage.reveal();
    }

    function closeApp() {
        root.openEntry = null;
        stage.reveal();
    }

    function requestInstall(packageName, source, name) {
        root.armedPackage = "";
        DepotBackend.install(packageName, source, name);
    }

    // Removing is armed first: one click shows the confirmation, a second
    // within three seconds runs it.
    function requestRemove(packageName, name) {
        if (root.armedPackage === packageName) {
            root.armedPackage = "";
            disarm.stop();
            DepotBackend.remove(packageName, name);
            return;
        }
        root.armedPackage = packageName;
        disarm.restart();
    }

    function resultMessage(result) {
        if (!result) return "";
        if (result.ok) return DepotStrings.t(result.action === "remove" ? "removedOk" : "installedOk").arg(result.name);
        switch (result.reason) {
        case "cancelled": return DepotStrings.t("cancelled");
        case "denied": return DepotStrings.t("denied");
        case "no-agent": return DepotStrings.t("noAgentFail");
        case "busy": return DepotStrings.t("busy");
        case "timeout": return DepotStrings.t("timeout");
        case "invalid": return DepotStrings.t("invalid");
        case "no-helper": return DepotStrings.t("needsHelper");
        case "unsupported": return DepotStrings.t("unsupported");
        }
        return DepotStrings.t("failed").arg(result.name).arg(result.msg || String(result.code));
    }

    onVisibleChanged: {
        if (!root.visible) {
            root.armedPackage = "";
            return;
        }
        DepotBackend.refresh();
    }

    Timer {
        id: disarm
        interval: 3000
        onTriggered: root.armedPackage = ""
    }

    // Successful results clear themselves; failures stay until dismissed.
    Timer {
        id: resultTimeout
        interval: 6000
        onTriggered: DepotBackend.dismissResult()
    }

    Connections {
        target: DepotBackend
        function onLastResultChanged() {
            if (DepotBackend.lastResult && DepotBackend.lastResult.ok) resultTimeout.restart();
            else resultTimeout.stop();
        }
    }

    Item {
        id: shell
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_F) {
                root.openEntry = null;
                root.focusSearch();
                event.accepted = true;
            } else if (event.text && event.text.trim() !== "" && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier))) {
                let wasSearching = root.searching;
                root.openEntry = null;
                search.text += event.text;
                search.focusInput();
                search.deselect();
                if (!wasSearching) stage.reveal();
                event.accepted = true;
            }
        }

        Column {
            id: top
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 24
            anchors.leftMargin: 28
            anchors.rightMargin: 28
            spacing: 16

            DepotHeader {
                width: parent.width
            }

            DepotSearchField {
                id: search
                width: parent.width
                placeholder: DepotStrings.t("searchPlaceholder")
                onTextChanged: DepotBackend.search(search.text)
                onEscaped: shell.forceActiveFocus()
            }

            DepotNavBar {
                width: parent.width
                visible: !root.searching && root.openEntry === null
                current: root.tab
                onSelected: tabId => root.goTab(tabId)
            }

            Column {
                id: notices
                width: parent.width
                spacing: 8

                DepotNotice {
                    width: parent.width
                    visible: DepotBackend.lastResult !== null
                    tone: DepotBackend.lastResult && DepotBackend.lastResult.ok ? "success"
                        : (DepotBackend.lastResult && DepotBackend.lastResult.reason === "cancelled" ? "info" : "danger")
                    text: root.resultMessage(DepotBackend.lastResult)
                    dismissible: true
                    onDismissed: DepotBackend.dismissResult()
                }

                DepotNotice {
                    width: parent.width
                    visible: DepotBackend.detected && !DepotBackend.info.supported
                    tone: "danger"
                    text: DepotStrings.t("unsupported")
                }

                DepotNotice {
                    width: parent.width
                    visible: DepotBackend.detected && DepotBackend.info.supported && !DepotBackend.info.polkitAgent
                    tone: "warning"
                    text: DepotStrings.t("noAgent")
                }

                DepotNotice {
                    width: parent.width
                    visible: DepotBackend.detected && DepotBackend.info.backend === "pacman" && !DepotBackend.info.aurHelper
                    tone: "info"
                    text: DepotStrings.t("noHelper")
                }
            }
        }

        Flickable {
            id: content
            anchors.top: top.bottom
            anchors.topMargin: 18
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            contentWidth: width
            contentHeight: stage.implicitHeight + 28
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            maximumFlickVelocity: 3200

            Item {
                id: stage
                width: content.width - 14
                implicitHeight: body.implicitHeight
                opacity: 1

                transform: Translate { id: stageShift; y: 0 }

                NumberAnimation {
                    id: revealOpacity
                    target: stage; property: "opacity"; from: 0; to: 1
                    duration: 190; easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    id: revealShift
                    target: stageShift; property: "y"; from: 10; to: 0
                    duration: 260; easing.type: Easing.OutCubic
                }

                function reveal() {
                    revealOpacity.stop();
                    revealShift.stop();
                    stage.opacity = 0;
                    stageShift.y = 10;
                    revealOpacity.start();
                    revealShift.start();
                }

            Column {
                id: body
                width: stage.width

                // App detail page takes over whenever one is open.
                DepotAppDetailPage {
                    width: body.width
                    visible: root.openEntry !== null
                    entry: root.openEntry || ({})
                    armedPackage: root.armedPackage
                    onInstallRequested: (packageName, source, name) => root.requestInstall(packageName, source, name)
                    onRemoveRequested: (packageName, name) => root.requestRemove(packageName, name)
                    onBack: root.closeApp()
                }

                // Search results replace whatever tab is selected while typing.
                Column {
                    width: body.width
                    visible: root.searching && root.openEntry === null
                    spacing: 6

                    Row {
                        leftPadding: 12
                        spacing: 10

                        Text {
                            text: DepotStrings.t("results").toUpperCase()
                            color: DepotTheme.overlay0
                            font.family: DepotTheme.mono
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            font.letterSpacing: 1.4
                        }
                        Text {
                            visible: DepotBackend.searching
                            text: DepotStrings.t("searching")
                            color: DepotTheme.overlay0
                            font.family: DepotTheme.sans
                            font.pixelSize: 11
                        }
                    }

                    Repeater {
                        model: root.searching ? DepotBackend.results : []

                        DepotPackageRow {
                            required property var modelData
                            width: body.width
                            entry: modelData
                            armedPackage: root.armedPackage
                            opacity: DepotBackend.searching ? 0.55 : 1
                            onInstallRequested: (packageName, source, name) => root.requestInstall(packageName, source, name)
                            onRemoveRequested: (packageName, name) => root.requestRemove(packageName, name)
                        }
                    }

                    Column {
                        visible: !DepotBackend.searching && DepotBackend.resultsQuery !== "" && DepotBackend.results.length === 0
                        leftPadding: 12
                        topPadding: 18
                        spacing: 6

                        Text {
                            text: DepotStrings.t("noResults").arg(DepotBackend.resultsQuery)
                            color: DepotTheme.text
                            font.family: DepotTheme.sans
                            font.pixelSize: 15
                            font.weight: Font.Medium
                        }
                        Text {
                            text: DepotStrings.t("noResultsHint")
                            color: DepotTheme.subtext0
                            font.family: DepotTheme.sans
                            font.pixelSize: 13
                        }
                    }
                }

                DepotExplorePage {
                    width: body.width
                    visible: !root.searching && root.openEntry === null && root.tab === "explore"
                    onOpened: entry => root.openApp(entry)
                }

                DepotCategoriesPage {
                    width: body.width
                    visible: !root.searching && root.openEntry === null && root.tab === "categories"
                    onOpened: entry => root.openApp(entry)
                }

                DepotInstalledPage {
                    width: body.width
                    visible: !root.searching && root.openEntry === null && root.tab === "installed"
                    armedPackage: root.armedPackage
                    onInstallRequested: (packageName, source, name) => root.requestInstall(packageName, source, name)
                    onRemoveRequested: (packageName, name) => root.requestRemove(packageName, name)
                    onOpened: entry => root.openApp(entry)
                }

                DepotUpdatesPage {
                    width: body.width
                    visible: !root.searching && root.openEntry === null && root.tab === "updates"
                }

                DepotSettingsPage {
                    width: body.width
                    visible: !root.searching && root.openEntry === null && root.tab === "settings"
                }

                Text {
                    visible: !root.searching && root.openEntry === null && root.tab === "explore" && !DepotBackend.featuredLoaded
                    leftPadding: 12
                    text: DepotStrings.t("loading")
                    color: DepotTheme.overlay0
                    font.family: DepotTheme.sans
                    font.pixelSize: 13
                }
            }
            }
        }

        DepotScrollBar {
            flickable: content
            anchors.top: content.top
            anchors.bottom: content.bottom
            anchors.right: parent.right
            anchors.rightMargin: 8
        }
    }
}
