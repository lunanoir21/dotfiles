import QtQuick
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../core"

Item {
    id: window
    focus: true

    // --- Responsive Scaling Logic ---
    Scaler {
        id: scaler
        currentWidth: Screen.width
    }
    
    function s(val) { 
        return scaler.s(val); 
    }

    // -------------------------------------------------------------------------
    // COLORS (Expanded Dynamic Matugen Palette)
    // -------------------------------------------------------------------------
    MatugenColors { id: _theme }
    
    readonly property color base: _theme.base
    readonly property color mantle: _theme.mantle
    readonly property color crust: _theme.crust
    readonly property color text: _theme.text
    readonly property color subtext0: _theme.subtext0
    readonly property color overlay0: _theme.overlay0 || "#6c7086"
    readonly property color overlay1: _theme.overlay1
    readonly property color surface0: _theme.surface0
    readonly property color surface1: _theme.surface1
    readonly property color surface2: _theme.surface2
    
    readonly property color mauve: _theme.mauve || "#cba6f7"
    readonly property color pink: _theme.pink
    readonly property color red: _theme.red
    readonly property color maroon: _theme.maroon
    readonly property color peach: _theme.peach
    readonly property color yellow: _theme.yellow
    readonly property color green: _theme.green
    readonly property color teal: _theme.teal
    readonly property color sapphire: _theme.sapphire
    readonly property color blue: _theme.blue

    // -------------------------------------------------------------------------
    // STATE & LOGIC
    // -------------------------------------------------------------------------
    property var allApps: []
    property var dockPinned: []
    property bool pinMenuOpen: false
    property var pinMenuApp: ({})
    property real pinMenuX: 0
    property real pinMenuY: 0
    readonly property string pinScript: Quickshell.env("HOME")
        + "/.config/hypr/scripts/quickshell/widgets/applauncher/dock_pins.sh"
    readonly property string settingsPath: Quickshell.env("HOME")
        + "/.config/hypr/settings.json"

    Process {
        id: appFetcher
        running: true
        command: ["bash", "-c", "python3 " + Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/widgets/applauncher/app_fetcher.py"]
        
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    if (this.text && this.text.trim().length > 0) {
                        window.allApps = JSON.parse(this.text);
                        filterApps("");
                    }
                } catch(e) {
                    console.log("Error parsing apps list: ", e);
                }
            }
        }
    }

    Process {
        id: dockPinReader
        running: true
        command: ["bash", window.pinScript, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    window.dockPinned = JSON.parse(this.text.trim());
                } catch (error) {
                    window.dockPinned = [];
                }
            }
        }
    }

    Process {
        id: dockPinWriter
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    window.dockPinned = JSON.parse(this.text.trim());
                } catch (error) {
                    window.refreshDockPins();
                }
            }
        }
    }

    FileView {
        path: window.settingsPath
        watchChanges: true
        preload: false
        blockAllReads: true
        onFileChanged: dockPinRefresh.restart()
        onLoadFailed: error => {}
    }

    Timer {
        id: dockPinRefresh
        interval: 120
        repeat: false
        onTriggered: window.refreshDockPins()
    }

    function refreshDockPins() {
        if (!dockPinReader.running) dockPinReader.running = true;
    }

    function pinIdForApp(app) {
        if (!app) return "";
        return String(app.desktopId || app.icon || app.name || "")
            .replace(/\.desktop$/i, "").toLowerCase();
    }

    function isDockPinned(app) {
        const id = window.pinIdForApp(app);
        for (let i = 0; i < window.dockPinned.length; i++) {
            if (String(window.dockPinned[i]).toLowerCase() === id) return true;
        }
        return false;
    }

    function showPinMenu(app, sourceItem, mouse) {
        const point = sourceItem.mapToItem(window, mouse.x, mouse.y);
        window.pinMenuApp = app;
        window.pinMenuX = Math.max(window.s(10),
            Math.min(point.x, window.width - pinMenu.width - window.s(10)));
        window.pinMenuY = Math.max(window.s(10),
            Math.min(point.y, window.height - pinMenu.height - window.s(10)));
        window.pinMenuOpen = true;
    }

    function toggleDockPin() {
        const id = window.pinIdForApp(window.pinMenuApp);
        if (!id || dockPinWriter.running) return;
        const action = window.isDockPinned(window.pinMenuApp) ? "remove" : "add";
        dockPinWriter.command = ["bash", window.pinScript, action, id];
        dockPinWriter.running = true;
        window.pinMenuOpen = false;
    }

    ListModel {
        id: appModel
    }

    // --- KEYBOARD NAV TRACKING (For Smart Highlight Morphing) ---
    property bool isKeyboardNav: false
    Timer {
        id: keyboardNavTimer
        interval: 500
        repeat: false
        onTriggered: window.isKeyboardNav = false
    }

    // --- SMART DIFFING FILTER ---
    function filterApps(query) {
        // Disable morphing behavior so the highlight box sticks to the flying item
        window.isKeyboardNav = false;
        if (keyboardNavTimer.running) keyboardNavTimer.stop();

        appList.currentIndex = -1;
        appList.positionViewAtBeginning();

        let q = query.toLowerCase();
        let filtered = [];
        
        for (let i = 0; i < allApps.length; i++) {
            if (allApps[i].name.toLowerCase().includes(q)) {
                filtered.push(allApps[i]);
            }
        }

        for (let i = appModel.count - 1; i >= 0; i--) {
            let currentName = appModel.get(i).name;
            let keep = false;
            for (let j = 0; j < filtered.length; j++) {
                if (filtered[j].name === currentName) {
                    keep = true;
                    break;
                }
            }
            if (!keep) {
                appModel.remove(i);
            }
        }

        for (let i = 0; i < filtered.length; i++) {
            let targetApp = filtered[i];
            
            if (i < appModel.count) {
                if (appModel.get(i).name !== targetApp.name) {
                    let foundIdx = -1;
                    for (let j = i + 1; j < appModel.count; j++) {
                        if (appModel.get(j).name === targetApp.name) {
                            foundIdx = j;
                            break;
                        }
                    }
                    if (foundIdx !== -1) {
                        appModel.move(foundIdx, i, 1);
                    } else {
                        appModel.insert(i, targetApp);
                    }
                }
            } else {
                appModel.append(targetApp);
            }
        }
        
        if (appModel.count > 0) {
            appList.currentIndex = 0;
        }
    }

    function launchApp(execStr) {
        Quickshell.execDetached(["hyprctl", "dispatch", "exec", "--", execStr]);
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"]);
    }

    // --- AGGRESSIVE FOCUS MANAGEMENT ---
    Timer {
        id: focusTimer
        interval: 50
        running: true
        repeat: false
        onTriggered: searchInput.forceActiveFocus()
    }

    Connections {
        target: window
        function onVisibleChanged() {
            if (window.visible) {
                window.refreshDockPins();
                focusTimer.restart();
                introPhaseAnim.restart();
            } else {
                window.pinMenuOpen = false;
            }
        }
    }

    Keys.onEscapePressed: {
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"]);
        event.accepted = true;
    }

    // --- BACKGROUND ORBIT ANIMATION ---
    property real globalOrbitAngle: 0
    NumberAnimation on globalOrbitAngle {
        from: 0; to: Math.PI * 2; duration: 90000; loops: Animation.Infinite; running: true
    }

    // --- MAIN INTRO ANIMATION ---
    property real introPhase: 0
    NumberAnimation on introPhase {
        id: introPhaseAnim
        from: 0; to: 1; duration: 600; easing.type: Easing.OutExpo; running: true
    }

    // -------------------------------------------------------------------------
    // UI LAYOUT
    // -------------------------------------------------------------------------
    Rectangle {
        id: mainBg
        width: parent.width
        
        // --- DYNAMIC HEIGHT CALCULATION (Bottom-up Shrinking) ---
        property real searchHeight: window.s(65)
        property real separatorHeight: 1
        property real itemHeight: window.s(60)
        property real listSpacing: window.s(4)
        property real maxListHeight: (8 * itemHeight) + (7 * listSpacing)
        
        property real targetListHeight: appModel.count === 0 ? 0 : Math.min((appModel.count * itemHeight) + ((appModel.count - 1) * listSpacing), maxListHeight)
        property real targetMargins: appModel.count > 0 ? window.s(20) : 0

        // Smoothly animated properties for elegant container morphing
        property real animatedListHeight: targetListHeight
        property real animatedMargins: targetMargins

        Behavior on animatedListHeight { 
            NumberAnimation { duration: 500; easing.type: Easing.OutExpo } 
        }
        Behavior on animatedMargins { 
            NumberAnimation { duration: 500; easing.type: Easing.OutExpo } 
        }
        
        height: searchHeight + separatorHeight + animatedMargins + animatedListHeight

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter

        radius: window.s(16)
        color: Qt.rgba(window.base.r, window.base.g, window.base.b, 1.0)
        border.color: window.surface1
        border.width: 1
        clip: true

        transform: Translate { y: (window.introPhase - 1) * window.s(60) }
        opacity: window.introPhase

        // --- AMBIENT BLOBS ---
        Rectangle {
            width: parent.width * 0.8; height: width; radius: width / 2
            x: (parent.width / 2 - width / 2) + Math.cos(window.globalOrbitAngle * 2) * window.s(150)
            y: (parent.height / 2 - height / 2) + Math.sin(window.globalOrbitAngle * 2) * window.s(100)
            opacity: 0.08
            color: window.mauve
            Behavior on color { ColorAnimation { duration: 1000 } }
        }
        
        Rectangle {
            width: parent.width * 0.9; height: width; radius: width / 2
            x: (parent.width / 2 - width / 2) + Math.sin(window.globalOrbitAngle * 1.5) * window.s(-150)
            y: (parent.height / 2 - height / 2) + Math.cos(window.globalOrbitAngle * 1.5) * window.s(-100)
            opacity: 0.06
            color: window.blue
            Behavior on color { ColorAnimation { duration: 1000 } }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // --- SEARCH BAR ---
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: mainBg.searchHeight
                color: "transparent"
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: window.s(15)
                    anchors.leftMargin: window.s(20)
                    anchors.rightMargin: window.s(20)
                    spacing: window.s(15)

                    Text {
                        text: ""
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: window.s(18)
                        color: searchInput.activeFocus ? window.mauve : window.subtext0
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    TextField {
                        id: searchInput
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        background: Item {} 
                        color: window.text
                        font.family: "JetBrains Mono"
                        font.pixelSize: window.s(16)
                        
                        placeholderText: "Search..."
                        placeholderTextColor: window.subtext0 
                        
                        verticalAlignment: TextInput.AlignVCenter
                        focus: true

                        onTextChanged: filterApps(text)

                        Keys.onDownPressed: {
                            window.isKeyboardNav = true;
                            keyboardNavTimer.restart();
                            if (appList.currentIndex < appModel.count - 1) {
                                appList.currentIndex++;
                            }
                            event.accepted = true;
                        }
                        Keys.onUpPressed: {
                            window.isKeyboardNav = true;
                            keyboardNavTimer.restart();
                            if (appList.currentIndex > 0) {
                                appList.currentIndex--;
                            }
                            event.accepted = true;
                        }
                        Keys.onReturnPressed: {
                            if (appList.currentIndex >= 0 && appList.currentIndex < appModel.count) {
                                launchApp(appModel.get(appList.currentIndex).exec);
                            }
                            event.accepted = true;
                        }
                        Keys.onEscapePressed: {
                            Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"]);
                            event.accepted = true;
                        }
                    }
                }
            }

            // --- SEPARATOR ---
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: mainBg.separatorHeight
                color: Qt.rgba(window.surface1.r, window.surface1.g, window.surface1.b, 0.5)
            }

            // --- APPLICATION LIST ---
            ListView {
                id: appList
                Layout.fillWidth: true
                
                Layout.preferredHeight: mainBg.animatedListHeight
                Layout.topMargin: mainBg.animatedMargins / 2
                Layout.bottomMargin: mainBg.animatedMargins / 2
                Layout.leftMargin: window.s(10)
                Layout.rightMargin: window.s(10)
                
                // clip: true is critical — it masks items that are outside the
                // visible list area so they cannot bleed through during transitions.
                clip: true
                model: appModel
                spacing: mainBg.listSpacing
                currentIndex: 0
                boundsBehavior: Flickable.StopAtBounds

                highlightFollowsCurrentItem: false

                onCurrentIndexChanged: {
                    if (currentIndex >= 0) {
                        positionViewAtIndex(currentIndex, ListView.Contain);
                    }
                }

                // --- LIST ITEM TRANSITIONS ---
                // Key fix: NO z-layer tricks. The ListView's own clip:true handles
                // masking. Items animate only opacity + scale so they never visually
                // "hang" outside the clipped region. The displaced transition slides
                // existing items to their new positions without fighting the add/remove.

                populate: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 550; easing.type: Easing.OutExpo }
                        NumberAnimation { property: "scale"; from: 0.88; to: 1; duration: 600; easing.type: Easing.OutExpo }
                    }
                }

                add: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 380; easing.type: Easing.OutExpo }
                        NumberAnimation { property: "scale"; from: 0.88; to: 1; duration: 420; easing.type: Easing.OutExpo }
                    }
                }
                
                remove: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; to: 0; duration: 280; easing.type: Easing.OutExpo }
                        NumberAnimation { property: "scale"; to: 0.88; duration: 300; easing.type: Easing.OutExpo }
                    }
                }
                
                // displaced runs for items that are already in the list and just
                // need to slide to a new position — keep it simple and fast so it
                // finishes well before (or together with) the add transition.
                displaced: Transition {
                    NumberAnimation { properties: "x,y"; duration: 380; easing.type: Easing.OutExpo }
                }

                ScrollBar.vertical: ScrollBar {
                    active: true
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        implicitWidth: window.s(4)
                        radius: window.s(2)
                        color: window.surface2
                        opacity: 0.5
                    }
                }

                // --- MATTE MORPHING HIGHLIGHT ---
                highlight: Item {
                    z: 0 
                    
                    Rectangle {
                        id: activeHighlight
                        x: 0
                        width: appList.width
                        radius: window.s(8)
                        color: window.mauve

                        property int prevIdx: 0
                        property int curIdx: appList.currentIndex

                        onCurIdxChanged: {
                            if (curIdx === -1) return; 
                            
                            if (curIdx > prevIdx) {
                                bottomAnim.duration = 250; topAnim.duration = 450;
                            } else if (curIdx < prevIdx) {
                                topAnim.duration = 250; bottomAnim.duration = 450;
                            }
                            prevIdx = curIdx;
                        }

                        // Track the current item's ACTUAL coordinates so it sticks mid-flight
                        property real targetTop: appList.currentItem ? appList.currentItem.y : 0
                        property real targetBottom: appList.currentItem ? (appList.currentItem.y + appList.currentItem.height) : 0

                        property real actualTop: targetTop
                        property real actualBottom: targetBottom

                        // Only enable the morphed lagging behavior during keyboard navigation.
                        // During search/diffing, it will instantly track the moving item.
                        Behavior on actualTop { 
                            enabled: window.isKeyboardNav
                            NumberAnimation { id: topAnim; easing.type: Easing.OutExpo } 
                        }
                        Behavior on actualBottom { 
                            enabled: window.isKeyboardNav
                            NumberAnimation { id: bottomAnim; easing.type: Easing.OutExpo } 
                        }

                        y: actualTop
                        height: actualBottom - actualTop
                        
                        // Makes the highlight respect the item's pop-in scale animation
                        scale: appList.currentItem ? appList.currentItem.scale : 1
                        
                        opacity: appList.count > 0 && appList.currentIndex >= 0 ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 300 } }
                    }
                }

                delegate: Item {
                    id: appDelegate
                    width: ListView.view.width
                    height: mainBg.itemHeight
                    z: 1 
                    
                    transformOrigin: Item.Center 

                    Rectangle {
                        anchors.fill: parent
                        radius: window.s(8)
                        color: "transparent"
                        
                        Rectangle {
                            anchors.fill: parent
                            radius: window.s(8)
                            color: window.surface0
                            opacity: ma.containsMouse && index !== appList.currentIndex ? 0.4 : 0
                            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutSine } }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: window.s(10)
                            anchors.leftMargin: window.s(12)
                            spacing: window.s(15)

                            // --- TINTED ICON MATTE BOX ---
                            Rectangle {
                                Layout.preferredWidth: window.s(40)
                                Layout.preferredHeight: window.s(40)
                                radius: window.s(12)
                                
                                color: index === appList.currentIndex ? window.crust : window.surface0
                                border.width: 0 
                                clip: true
                                
                                property real activeScale: index === appList.currentIndex ? 1.15 : 1
                                scale: activeScale
                                Behavior on activeScale { 
                                    NumberAnimation { duration: 500; easing.type: Easing.OutBack; easing.overshoot: 1.5 } 
                                }
                                Behavior on color { ColorAnimation { duration: 300; easing.type: Easing.OutExpo } }

                                Image {
                                    anchors.centerIn: parent
                                    width: window.s(24)
                                    height: window.s(24)
                                    source: model.icon.startsWith("/") ? "file://" + model.icon : "image://icon/" + model.icon
                                    sourceSize: Qt.size(64, 64)
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    smooth: true
                                    mipmap: true
                                }
                                
                                // The Matugen Tint Overlay
                                Rectangle {
                                    anchors.fill: parent
                                    radius: window.s(12) 
                                    
                                    color: window.mauve
                                    opacity: index === appList.currentIndex ? 0.25 : 0.08 
                                    
                                    Behavior on opacity { 
                                        NumberAnimation { duration: 300; easing.type: Easing.OutExpo } 
                                    }
                                }
                            }

                            Text {
                                id: appLabel
                                Layout.fillWidth: true
                                text: model.name
                                font.family: "JetBrains Mono"
                                font.pixelSize: window.s(14)
                                font.weight: index === appList.currentIndex ? Font.Bold : Font.Medium
                                color: index === appList.currentIndex ? window.crust : window.text
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                                
                                property real textShift: index === appList.currentIndex ? window.s(6) : 0
                                transform: Translate { x: appLabel.textShift }
                                
                                Behavior on textShift { 
                                    NumberAnimation { duration: 500; easing.type: Easing.OutExpo } 
                                }
                                Behavior on color { ColorAnimation { duration: 300; easing.type: Easing.OutExpo } }
                            }

                            Text {
                                visible: window.isDockPinned({
                                    name: model.name,
                                    icon: model.icon,
                                    desktopId: model.desktopId
                                })
                                text: "󰐕"
                                color: index === appList.currentIndex ? window.crust : window.mauve
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: window.s(13)
                                opacity: 0.86
                            }
                        }

                        MouseArea {
                            id: ma
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: (mouse) => {
                                appList.currentIndex = index;
                                if (mouse.button === Qt.RightButton) {
                                    window.showPinMenu({
                                        name: model.name,
                                        exec: model.exec,
                                        icon: model.icon,
                                        desktopId: model.desktopId
                                    }, appDelegate, mouse);
                                } else {
                                    launchApp(model.exec);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: 900
        visible: window.pinMenuOpen
        acceptedButtons: Qt.AllButtons
        onClicked: window.pinMenuOpen = false
    }

    Rectangle {
        id: pinMenu
        z: 901
        x: window.pinMenuX
        y: window.pinMenuY
        width: window.s(270)
        height: window.s(116)
        radius: window.s(15)
        visible: window.pinMenuOpen
        color: Qt.rgba(window.crust.r, window.crust.g, window.crust.b, 0.98)
        border.width: 1
        border.color: Qt.rgba(window.text.r, window.text.g, window.text.b, 0.14)
        opacity: window.pinMenuOpen ? 1 : 0
        scale: window.pinMenuOpen ? 1 : 0.94
        transformOrigin: Item.TopLeft

        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on scale {
            NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 0.7 }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: window.s(9)
            spacing: window.s(5)

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: window.s(42)
                Layout.leftMargin: window.s(5)
                Layout.rightMargin: window.s(5)
                spacing: window.s(10)

                Rectangle {
                    Layout.preferredWidth: window.s(34)
                    Layout.preferredHeight: window.s(34)
                    radius: window.s(10)
                    color: Qt.rgba(window.surface1.r, window.surface1.g, window.surface1.b, 0.72)

                    Image {
                        anchors.centerIn: parent
                        width: window.s(22)
                        height: window.s(22)
                        source: String(window.pinMenuApp.icon || "").startsWith("/")
                            ? "file://" + window.pinMenuApp.icon
                            : "image://icon/" + (window.pinMenuApp.icon || "application-x-executable")
                        sourceSize: Qt.size(64, 64)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: window.pinMenuApp.name || "Uygulama"
                        color: window.text
                        font.family: "JetBrains Mono"
                        font.pixelSize: window.s(11)
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        text: "Dock hızlı işlemi"
                        color: window.overlay1
                        font.family: "JetBrains Mono"
                        font.pixelSize: window.s(8)
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                Layout.leftMargin: window.s(5)
                Layout.rightMargin: window.s(5)
                color: Qt.rgba(window.text.r, window.text.g, window.text.b, 0.10)
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: window.s(10)
                color: pinAction.containsMouse
                    ? Qt.rgba(window.mauve.r, window.mauve.g, window.mauve.b, 0.18)
                    : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: window.s(12)
                    anchors.rightMargin: window.s(12)
                    spacing: window.s(11)

                    Text {
                        text: window.isDockPinned(window.pinMenuApp) ? "󰤱" : "󰐕"
                        color: window.mauve
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: window.s(15)
                    }

                    Text {
                        Layout.fillWidth: true
                        text: window.isDockPinned(window.pinMenuApp)
                            ? "Dock'tan çıkar" : "Dock'a sabitle"
                        color: window.text
                        font.family: "JetBrains Mono"
                        font.pixelSize: window.s(10)
                        font.weight: Font.Medium
                    }
                }

                MouseArea {
                    id: pinAction
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: window.toggleDockPin()
                }
            }
        }
    }
}
