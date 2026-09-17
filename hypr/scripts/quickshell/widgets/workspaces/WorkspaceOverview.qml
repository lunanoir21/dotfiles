import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../core"

Item {
    id: window
    focus: true

    // Main.qml gives every popup these shared loader properties.
    property var notifModel
    property var liveNotifs
    property real layoutWidth: 0
    property real layoutHeight: 0

    Scaler {
        id: scaler
        currentWidth: Screen.width
    }

    function s(value) { return scaler.s(value); }

    MatugenColors { id: mocha }

    function gray(source, alpha) {
        var value = source.r * 0.2126 + source.g * 0.7152 + source.b * 0.0722;
        return Qt.rgba(value, value, value, alpha === undefined ? source.a : alpha);
    }

    property var wsData: ({})
    property var monitorData: ({})
    property var workspaceMonitors: ({})
    property var monitorActiveWorkspaces: ({})
    property int activeWs: 1
    property int fallbackMonitor: 0
    property int draggingTargetWorkspace: -1
    property int draggingFromWorkspace: -1
    property real reveal: 0

    function normalizeAddress(address) {
        return String(address || "").toLowerCase().replace(/^0x/, "");
    }

    function toplevelForWindow(address, windowClass, title) {
        var model = ToplevelManager.toplevels;
        var values = model && model.values ? model.values : [];
        var wantedAddress = normalizeAddress(address);
        var className = String(windowClass || "").toLowerCase();
        var titleText = String(title || "");
        var classFallback = null;

        for (var i = 0; i < values.length; i++) {
            var candidate = values[i];
            var hyprToplevel = candidate ? candidate.HyprlandToplevel : null;
            if (hyprToplevel && normalizeAddress(hyprToplevel.address) === wantedAddress)
                return candidate;

            if (!classFallback && String(candidate.appId || "").toLowerCase() === className)
                classFallback = candidate;
            if (String(candidate.title || "") === titleText &&
                    String(candidate.appId || "").toLowerCase() === className)
                classFallback = candidate;
        }
        return classFallback;
    }

    function monitorForWorkspace(workspaceId) {
        var monitorId = workspaceMonitors[workspaceId];
        if (monitorId === undefined || monitorId === null) monitorId = fallbackMonitor;
        return monitorData[monitorId] || { x: 0, y: 0, width: 1920, height: 1080 };
    }

    function closeOverview() {
        if (!closeProcess.running) closeProcess.running = true;
    }

    function moveWindow(address, workspaceId) {
        if (!address || moveProcess.running) return;
        moveProcess.command = ["hyprctl", "dispatch", "movetoworkspacesilent",
                               String(workspaceId) + ",address:" + address];
        moveProcess.running = true;
    }

    Component.onCompleted: {
        fetchData.running = true;
        revealAnimation.start();
    }

    NumberAnimation {
        id: revealAnimation
        target: window
        property: "reveal"
        from: 0
        to: 1
        duration: 320
        easing.type: Easing.OutCubic
    }

    Shortcut {
        sequence: "Escape"
        onActivated: window.closeOverview()
    }

    Process {
        id: closeProcess
        command: [Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"]
    }

    Process {
        id: switchProcess
        onExited: window.closeOverview()
    }

    Process {
        id: moveProcess
        onExited: refreshTimer.restart()
    }

    Timer {
        id: refreshTimer
        interval: 170
        onTriggered: if (!fetchData.running) fetchData.running = true
    }

    Process {
        id: fetchData
        command: ["bash", "-c",
            "jq -cn --argjson clients \"$(hyprctl clients -j)\" " +
            "--argjson active \"$(hyprctl activeworkspace -j)\" " +
            "--argjson monitors \"$(hyprctl monitors -j)\" " +
            "--argjson workspaces \"$(hyprctl workspaces -j)\" " +
            "'{clients:$clients,active:$active,monitors:$monitors,workspaces:$workspaces}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var payload = JSON.parse(text.trim());
                    var clients = payload.clients || [];
                    var monitors = payload.monitors || [];
                    var workspaces = payload.workspaces || [];
                    var map = {};
                    var monitorMap = {};
                    var workspaceMonitorMap = {};
                    var activeMap = {};

                    for (var i = 1; i <= 10; i++) map[i] = [];

                    for (var m = 0; m < monitors.length; m++) {
                        var mon = monitors[m];
                        var monitorScale = mon.scale || 1;
                        var logicalWidth = mon.width / monitorScale;
                        var logicalHeight = mon.height / monitorScale;
                        if (mon.transform % 2 === 1) {
                            var swap = logicalWidth;
                            logicalWidth = logicalHeight;
                            logicalHeight = swap;
                        }
                        monitorMap[mon.id] = {
                            x: mon.x || 0,
                            y: mon.y || 0,
                            width: logicalWidth,
                            height: logicalHeight,
                            name: mon.name || ""
                        };
                        if (m === 0 || mon.focused) window.fallbackMonitor = mon.id;
                        if (mon.activeWorkspace && mon.activeWorkspace.id > 0)
                            activeMap[mon.activeWorkspace.id] = true;
                    }

                    for (var w = 0; w < workspaces.length; w++) {
                        var workspace = workspaces[w];
                        if (workspace.id >= 1 && workspace.id <= 10)
                            workspaceMonitorMap[workspace.id] = workspace.monitorID;
                    }

                    for (var c = 0; c < clients.length; c++) {
                        var client = clients[c];
                        var workspaceId = client.workspace ? client.workspace.id : -1;
                        if (workspaceId < 1 || workspaceId > 10) continue;
                        var monitorId = client.monitor;
                        var monitor = monitorMap[monitorId] || { x: 0, y: 0, width: 1920, height: 1080 };
                        workspaceMonitorMap[workspaceId] = monitorId;
                        map[workspaceId].push({
                            address: client.address || "",
                            title: client.title || client.class || "Pencere",
                            cls: client.class || "Pencere",
                            x: (client.at ? client.at[0] : 0) - monitor.x,
                            y: (client.at ? client.at[1] : 0) - monitor.y,
                            w: client.size ? client.size[0] : monitor.width,
                            h: client.size ? client.size[1] : monitor.height
                        });
                    }

                    window.activeWs = payload.active && payload.active.id ? payload.active.id : 1;
                    window.monitorData = monitorMap;
                    window.workspaceMonitors = workspaceMonitorMap;
                    window.monitorActiveWorkspaces = activeMap;
                    window.wsData = map;
                } catch (error) {
                    console.warn("Workspace overview verisi okunamadı:", error);
                }
            }
        }
    }

    Rectangle {
        id: overviewSurface
        anchors.fill: parent
        radius: window.s(32)
        color: window.gray(mocha.base, 0.94)
        border.color: window.gray(mocha.surface2, 0.7)
        border.width: window.s(1)
        opacity: window.reveal
        scale: 0.97 + window.reveal * 0.03

        Rectangle {
            anchors.fill: parent
            anchors.margins: window.s(1)
            radius: parent.radius - window.s(1)
            color: window.gray(mocha.mantle, 0.24)
        }

        GridLayout {
            id: workspaceGrid
            anchors.fill: parent
            anchors.margins: window.s(10)
            columns: 5
            rowSpacing: window.s(5)
            columnSpacing: window.s(5)

                Repeater {
                    model: 10

                    delegate: Rectangle {
                        id: workspaceCard
                        required property int index
                        readonly property int workspaceId: index + 1
                        readonly property int rowIndex: Math.floor(index / 5)
                        readonly property int columnIndex: index % 5
                        property var wins: window.wsData[workspaceId] || []
                        property var monitor: window.monitorForWorkspace(workspaceId)
                        property bool isActive: workspaceId === window.activeWs
                        property bool isMonitorActive: window.monitorActiveWorkspaces[workspaceId] === true
                        property bool hovered: workspaceMouse.containsMouse
                        property bool dragHovered: dropArea.containsDrag || window.draggingTargetWorkspace === workspaceId

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumWidth: window.s(170)
                        Layout.minimumHeight: window.s(120)
                        topLeftRadius: rowIndex === 0 && columnIndex === 0 ? window.s(24) : window.s(7)
                        topRightRadius: rowIndex === 0 && columnIndex === 4 ? window.s(24) : window.s(7)
                        bottomLeftRadius: rowIndex === 1 && columnIndex === 0 ? window.s(24) : window.s(7)
                        bottomRightRadius: rowIndex === 1 && columnIndex === 4 ? window.s(24) : window.s(7)
                        clip: false
                        color: dragHovered
                               ? window.gray(mocha.overlay1, 0.82)
                               : hovered
                                 ? window.gray(mocha.surface1, 0.86)
                                 : window.gray(mocha.surface0, 0.72)
                        border.color: dragHovered
                                      ? window.gray(mocha.text, 0.96)
                                      : isActive
                                        ? window.gray(mocha.text, 0.9)
                                        : isMonitorActive
                                          ? window.gray(mocha.subtext0, 0.72)
                                          : window.gray(mocha.surface2, 0.34)
                        border.width: dragHovered || isActive ? window.s(2) : window.s(1)

                        Behavior on color { ColorAnimation { duration: 140 } }
                        Behavior on border.color { ColorAnimation { duration: 140 } }

                        Text {
                            anchors.centerIn: parent
                            text: workspaceCard.workspaceId
                            color: window.gray(mocha.text, workspaceCard.wins.length ? 0.055 : 0.13)
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: window.s(70)
                            font.weight: Font.Bold
                        }

                        MouseArea {
                            id: workspaceMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (window.draggingFromWorkspace !== -1) return;
                                switchProcess.command = ["hyprctl", "dispatch", "workspace", String(workspaceCard.workspaceId)];
                                switchProcess.running = true;
                            }
                        }

                        DropArea {
                            id: dropArea
                            anchors.fill: parent
                            onEntered: window.draggingTargetWorkspace = workspaceCard.workspaceId
                            onExited: {
                                if (window.draggingTargetWorkspace === workspaceCard.workspaceId)
                                    window.draggingTargetWorkspace = -1;
                            }
                            onDropped: function(drop) {
                                if (drop.source && drop.source.windowAddress &&
                                        workspaceCard.workspaceId !== drop.source.sourceWorkspace) {
                                    window.moveWindow(drop.source.windowAddress, workspaceCard.workspaceId);
                                    drop.accept(Qt.MoveAction);
                                }
                            }
                        }

                        Item {
                            id: desktopMap
                            anchors.fill: parent
                            anchors.margins: window.s(7)
                            clip: false

                            Repeater {
                                model: workspaceCard.wins.length

                                delegate: Rectangle {
                                    id: thumbnail
                                    required property int index
                                    property var win: workspaceCard.wins[index]
                                    property string windowAddress: win.address || ""
                                    property int sourceWorkspace: workspaceCard.workspaceId
                                    property var liveToplevel: window.toplevelForWindow(windowAddress, win.cls, win.title)
                                    property var desktopEntry: DesktopEntries.heuristicLookup(win.cls || "")
                                    readonly property real mapScale: Math.min(
                                        desktopMap.width / Math.max(1, workspaceCard.monitor.width),
                                        desktopMap.height / Math.max(1, workspaceCard.monitor.height))
                                    property real homeX: Math.max(0, win.x * mapScale)
                                    property real homeY: Math.max(0, win.y * mapScale)
                                    readonly property real minimumScale: Math.max(
                                        mapScale,
                                        window.s(34) / Math.max(1, win.w),
                                        window.s(24) / Math.max(1, win.h))
                                    readonly property real thumbnailScale: Math.min(
                                        minimumScale,
                                        (desktopMap.width - homeX) / Math.max(1, win.w),
                                        (desktopMap.height - homeY) / Math.max(1, win.h))

                                    x: homeX
                                    y: homeY
                                    width: Math.max(window.s(2), win.w * thumbnailScale)
                                    height: Math.max(window.s(2), win.h * thumbnailScale)
                                    radius: window.s(6)
                                    color: window.gray(mocha.mantle, 0.96)
                                    border.color: windowMouse.drag.active
                                                  ? window.gray(mocha.text, 0.98)
                                                  : window.gray(mocha.overlay1, 0.66)
                                    border.width: windowMouse.drag.active || windowMouse.containsMouse ? window.s(2) : window.s(1)
                                    opacity: windowMouse.drag.active ? 0.66 : 1
                                    scale: windowMouse.containsMouse && !windowMouse.drag.active ? 1.025 : 1
                                    z: windowMouse.drag.active ? 1000 : index + 10
                                    clip: true

                                    Drag.active: windowMouse.drag.active
                                    Drag.source: thumbnail
                                    Drag.hotSpot.x: width / 2
                                    Drag.hotSpot.y: height / 2
                                    Drag.supportedActions: Qt.MoveAction

                                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                    Behavior on opacity { NumberAnimation { duration: 110 } }
                                    Behavior on border.color { ColorAnimation { duration: 120 } }

                                    ScreencopyView {
                                        id: livePreview
                                        anchors.fill: parent
                                        captureSource: window.reveal > 0.05 ? thumbnail.liveToplevel : null
                                        live: true

                                        Rectangle {
                                            anchors.fill: parent
                                            color: windowMouse.containsMouse
                                                   ? window.gray(mocha.text, 0.1)
                                                   : window.gray(mocha.crust, 0.025)
                                            Behavior on color { ColorAnimation { duration: 130 } }
                                        }
                                    }

                                    Rectangle {
                                        visible: !thumbnail.liveToplevel
                                        anchors.fill: parent
                                        radius: parent.radius
                                        color: window.gray(mocha.surface1, 0.94)
                                    }

                                    Image {
                                        id: appIcon
                                        anchors.centerIn: parent
                                        width: Math.min(parent.width, parent.height) * (Math.min(parent.width, parent.height) < window.s(45) ? 0.5 : 0.23)
                                        height: width
                                        source: Quickshell.iconPath(
                                                    thumbnail.desktopEntry ? thumbnail.desktopEntry.icon : String(thumbnail.win.cls || "").toLowerCase(),
                                                    "image-missing")
                                        sourceSize.width: width * 2
                                        sourceSize.height: height * 2
                                        mipmap: true
                                        opacity: windowMouse.containsMouse ? 1 : 0.9
                                        Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                    }

                                    MouseArea {
                                        id: windowMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                        drag.target: thumbnail
                                        drag.axis: Drag.XAndYAxis
                                        drag.threshold: window.s(5)
                                        onPressed: {
                                            window.draggingFromWorkspace = thumbnail.sourceWorkspace;
                                        }
                                        onReleased: {
                                            var targetWorkspace = window.draggingTargetWorkspace;
                                            if (drag.active) thumbnail.Drag.drop();
                                            if (targetWorkspace !== -1 && targetWorkspace !== thumbnail.sourceWorkspace &&
                                                    !moveProcess.running)
                                                window.moveWindow(thumbnail.windowAddress, targetWorkspace);
                                            thumbnail.x = thumbnail.homeX;
                                            thumbnail.y = thumbnail.homeY;
                                            window.draggingFromWorkspace = -1;
                                            window.draggingTargetWorkspace = -1;
                                        }
                                        onClicked: function(mouse) {
                                            if (!drag.active && mouse.button === Qt.LeftButton) {
                                                switchProcess.command = ["hyprctl", "dispatch", "focuswindow",
                                                                         "address:" + thumbnail.windowAddress];
                                                switchProcess.running = true;
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
