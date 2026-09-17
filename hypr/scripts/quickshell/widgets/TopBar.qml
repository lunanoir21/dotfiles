import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import "../core"

Variants {
    model: Quickshell.screens

    delegate: Component {
        PanelWindow {
            id: barWindow
            property bool pendingReload: false
            
	    Caching { id: paths }

	    Component.onCompleted: {
 	        console.log("runDir:", paths.runDir)
 	        console.log("manual path:", paths.runDir + "/workspaces")
 	        console.log("env test:", Quickshell.env("QS_RUN_WORKSPACES"))
 	        console.log("wsPath:", paths.getRunDir("workspaces"))
	    }


            IpcHandler {
                target: "topbar"
                function forceReload() {
                    Quickshell.reload(true) 
                }
                function queueReload() {
                    if (!barWindow.isSettingsOpen) {
                        Quickshell.reload(true)
                    } else {
                        barWindow.pendingReload = true
                    }
                }
            }

            required property var modelData
            screen: modelData

            anchors {
                top: true
                left: true
                right: true
            }

            Scaler {
                id: scaler
                currentWidth: barWindow.width
            }

            property real baseScale: scaler.baseScale

            function s(val) { 
                return scaler.s(val); 
            }

            property int barHeight: s(48)

            height: barHeight
            margins { top: s(8); bottom: 0; left: s(4); right: s(4) }
            exclusiveZone: barHeight 
            color: "transparent"

            MatugenColors {
                id: mocha
            }

            property bool isRecording: false

            property int workspaceCount: Settings.workspaceCount

            // Workspace sayısı değişince daemon'un yeni sayıyla yeniden
            // başlaması gerekiyor; eskiden bunu settings.json okuyucusu yapardı.
            onWorkspaceCountChanged: {
                wsDaemon.running = false;
                wsDaemon.running = true;
            }
            
            property string activeWidget: "" 
            property bool isSettingsOpen: activeWidget === "settings"

            // Not: Ayarlar eskiden sol kenardan açılan bir panel olduğu için
            // bardaki kutular ona yer açmak üzere sağa kayardı. Ayarlar artık
            // ekranın ortasında kendi penceresinde açılıyor; kaydırma yersiz
            // kaldı ve kutular olduğu yerde duruyor.

            onIsSettingsOpenChanged: {
                if (!barWindow.isSettingsOpen && barWindow.pendingReload) {
                    barWindow.pendingReload = false;
                    Quickshell.reload(true);
                }
            }

            Process {
                id: widgetPoller
                command: ["bash", "-c", "cat " + paths.runDir + "/current_widget 2>/dev/null || echo ''"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (barWindow.activeWidget !== txt) barWindow.activeWidget = txt;
                    }
                }
            }

            Process {
                id: widgetWatcher
                command: ["bash", "-c", "while [ ! -f " + paths.runDir + "/current_widget ]; do sleep 1; done; exec inotifywait -qq -e modify,close_write " + paths.runDir + "/current_widget"]
                running: true
                onExited: {
                    widgetPoller.running = false;
                    widgetPoller.running = true;
                    running = false;
                    running = true;
                }
            }
            
            Process {
                id: recPoller
                command: ["bash", "-c", "if [ -s " + paths.getCacheDir("recording") + "/rec_pid ] && kill -0 $(cat " + paths.getCacheDir("recording") + "/rec_pid) 2>/dev/null; then echo '1'; else echo '0'; fi"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        barWindow.isRecording = (this.text.trim() === "1");
                    }
                }
            }

            Process {
 	    	id: recWatcher
 		running: true
 		command: ["bash", "-c", "exec inotifywait -qq -e create,delete,modify,close_write " + paths.getCacheDir("recording") + "/ 2>/dev/null || sleep 2"]
 	        onExited: {
 	        	recPoller.running = false;
 	         	recPoller.running = true;
 	         	running = false;
 	         	running = true;
 	        }
	    }	  
            property bool isStartupReady: false
            Timer { interval: 10; running: true; onTriggered: barWindow.isStartupReady = true }
            
            property bool startupCascadeFinished: false
            Timer { interval: 1000; running: true; onTriggered: barWindow.startupCascadeFinished = true }
            
            property bool isDataReady: false
            Timer { interval: 600; running: true; onTriggered: barWindow.isDataReady = true }
            
            property string timeStr: ""
            property string fullDateStr: ""
            property int typeInIndex: 0
            property string dateStr: fullDateStr.substring(0, typeInIndex)

            property string weatherIcon: ""
            property string weatherTemp: "--°"
            property string weatherHex: mocha.yellow
            
            ListModel {
                id: workspacesModel 
                property int activeIndex: 0
            }
            
            property var musicData: { "status": "Stopped", "title": "", "artUrl": "", "timeStr": "" }

            property string displayTitle: ""
            property string displayTime: ""
            property string displayArtUrl: ""

            onMusicDataChanged: {
                if (musicData && musicData.status !== "Stopped" && musicData.title !== "") {
                    displayTitle = musicData.title;
                    displayTime = musicData.timeStr;
                    displayArtUrl = musicData.artUrl;
                }
            }

            property bool isMediaActive: barWindow.musicData.status !== "Stopped" && barWindow.musicData.title !== ""

            Process {
                id: wsDaemon
                command: ["bash", "-c", "~/.config/hypr/scripts/workspaces.sh"]
                running: true
            }

            Process {
		id: wsReader
		running: true
                command: ["cat", paths.getRunDir("workspaces") + "/workspaces.json"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "") {
                            try { 
                                let newData = JSON.parse(txt);
                                
                                while (workspacesModel.count < newData.length) {
                                    workspacesModel.append({ "wsId": "", "wsState": "" });
                                }
                                
                                while (workspacesModel.count > newData.length) {
                                    workspacesModel.remove(workspacesModel.count - 1);
                                }
                                
                                let newActive = -1;

                                for (let i = 0; i < newData.length; i++) {
                                    if (newData[i].state === "active") newActive = i;

                                    if (workspacesModel.get(i).wsState !== newData[i].state) {
                                        workspacesModel.setProperty(i, "wsState", newData[i].state);
                                    }
                                    if (workspacesModel.get(i).wsId !== newData[i].id.toString()) {
                                        workspacesModel.setProperty(i, "wsId", newData[i].id.toString());
                                    }
                                }

                                if (newActive !== -1 && workspacesModel.activeIndex !== newActive) {
                                    workspacesModel.activeIndex = newActive;
                                }

                            } catch(e) {}
                        }
                    }
                }
            }

            Process {
                id: wsWatcher
                running: true
                command: ["bash", "-c", "inotifywait -qq -e close_write,modify " + paths.getRunDir("workspaces") + "/workspaces.json"]
                onExited: {
                    wsReader.running = false;
                    wsReader.running = true;
                    running = false;
                    running = true;
                }
            }

            Process {
                id: musicForceRefresh
                running: true
                command: ["bash", "-c", "bash ~/.config/hypr/scripts/quickshell/widgets/music/music_info.sh | tee " + paths.getRunDir("music") + "/music_info.json"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "") {
                            try { barWindow.musicData = JSON.parse(txt); } catch(e) {}
                        }
                    }
                }
            }

            Timer {
                interval: 1000
                running: barWindow.musicData !== null && barWindow.musicData.status === "Playing"
                repeat: true
                onTriggered: {
                    if (!barWindow.musicData || barWindow.musicData.status !== "Playing") return;
                    if (!barWindow.musicData.timeStr || barWindow.musicData.timeStr === "") return;

                    let parts = barWindow.musicData.timeStr.split(" / ");
                    if (parts.length !== 2) return;

                    let posParts = parts[0].split(":").map(Number);
                    let lenParts = parts[1].split(":").map(Number);

                    let posSecs = (posParts.length === 3) 
                        ? (posParts[0] * 3600 + posParts[1] * 60 + posParts[2]) 
                        : (posParts[0] * 60 + posParts[1]);

                    let lenSecs = (lenParts.length === 3) 
                        ? (lenParts[0] * 3600 + lenParts[1] * 60 + lenParts[2]) 
                        : (lenParts[0] * 60 + lenParts[1]);

                    if (isNaN(posSecs) || isNaN(lenSecs)) return;

                    posSecs++;
                    if (posSecs > lenSecs) posSecs = lenSecs;

                    let newPosStr = "";
                    if (posParts.length === 3) {
                        let h = Math.floor(posSecs / 3600);
                        let m = Math.floor((posSecs % 3600) / 60);
                        let s = posSecs % 60;
                        newPosStr = h + ":" + (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
                    } else {
                        let m = Math.floor(posSecs / 60);
                        let s = posSecs % 60;
                        newPosStr = (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
                    }

                    let newData = Object.assign({}, barWindow.musicData);
                    newData.timeStr = newPosStr + " / " + parts[1];
                    newData.positionStr = newPosStr;
                    if (lenSecs > 0) newData.percent = (posSecs / lenSecs) * 100;
                    
                    barWindow.musicData = newData;
                }
            }

            Process {
                id: mprisWatcher
                running: true
                command: ["bash", "-c", "dbus-monitor --session \"type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',arg0='org.mpris.MediaPlayer2.Player'\" \"type='signal',interface='org.mpris.MediaPlayer2.Player',member='Seeked'\" 2>/dev/null | grep -m 1 'member=' > /dev/null || sleep 2"]
                onExited: {
                    musicForceRefresh.running = false;
                    musicForceRefresh.running = true;
                    running = false;
                    running = true;
                }
            }

            Timer {
                id: artRetryTimer
                interval: 500
                repeat: true
                running: barWindow.displayArtUrl && barWindow.displayArtUrl.indexOf("placeholder_blank.png") !== -1
                onTriggered: {
                    musicForceRefresh.running = false;
                    musicForceRefresh.running = true;
                }
            }

            // kb / audio / network / bt / battery watcher çiftleri buradan
            // KeyboardData, AudioData, NetworkData, BluetoothData, BatteryData
            // singleton'larına taşındı. Abonelik aşağıdaki Component.onCompleted'da.

            Process {
                id: weatherPoller
                command: ["bash", "-c", `
                    echo "$(~/.config/hypr/scripts/quickshell/widgets/calendar/weather.sh --current-icon)"
                    echo "$(~/.config/hypr/scripts/quickshell/widgets/calendar/weather.sh --current-temp)"
                    echo "$(~/.config/hypr/scripts/quickshell/widgets/calendar/weather.sh --current-hex)"
                `]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let lines = this.text.trim().split("\n");
                        if (lines.length >= 3) {
                            barWindow.weatherIcon = lines[0];
                            barWindow.weatherTemp = lines[1];
                            barWindow.weatherHex = lines[2] || mocha.yellow;
                        }
                    }
                }
            }
            Timer { interval: 150000; running: true; repeat: true; triggeredOnStart: true; onTriggered: { weatherPoller.running = false; weatherPoller.running = true; } }


            Timer {
                interval: 1000; running: true; repeat: true; triggeredOnStart: true
                onTriggered: {
                    let d = new Date();
                    barWindow.timeStr = Qt.formatDateTime(d, "HH:mm:ss");
                    barWindow.fullDateStr = Qt.formatDateTime(d, "dddd, MMMM dd");
                    if (barWindow.typeInIndex >= barWindow.fullDateStr.length) {
                        barWindow.typeInIndex = barWindow.fullDateStr.length;
                    }
                }
            }

            Timer {
                id: typewriterTimer
                interval: 40
                running: barWindow.isStartupReady && barWindow.typeInIndex < barWindow.fullDateStr.length
                repeat: true
                onTriggered: barWindow.typeInIndex += 1
            }

            Item {
                anchors.fill: parent

                TopLeftCluster {
                    id: workspacesBox
                    workspaceModel: workspacesModel
                    theme: mocha
                    uiScale: barWindow.baseScale
                    enabledState: !barWindow.isSettingsOpen
                    y: (parent.height - barWindow.barHeight) / 2
                    property real defaultX: 0
                    x: defaultX
                    onSearchRequested: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle applauncher"])
                    onSettingsRequested: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle settings"])
                    onWorkspaceRequested: workspaceId => Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh " + workspaceId])
                }

                Rectangle {
                    id: mediaBox
                    color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.75)
                    radius: barWindow.s(14); border.width: 1; border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.05)
                    y: (parent.height - barWindow.barHeight) / 2
                    height: 0
                    clip: true 
                    
                    width: 0
                    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

                    property real defaultX: workspacesBox.defaultX + workspacesBox.width + (workspacesBox.width > 0 ? barWindow.s(4) : 0)
                    x: defaultX

                    visible: false
                    enabled: false
                    opacity: 0
                    Behavior on opacity { NumberAnimation { duration: 400 } }
                    
                    Item {
                        id: mediaLayoutContainer
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: barWindow.s(12)
                        height: parent.height
                        width: innerMediaLayout.implicitWidth
                        
                        opacity: barWindow.isMediaActive ? 1.0 : 0.0
                        transform: Translate { 
                            x: barWindow.isMediaActive ? 0 : barWindow.s(-20) 
                            Behavior on x { NumberAnimation { duration: 700; easing.type: Easing.OutQuint } }
                        }
                        Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

                        Row {
                            id: innerMediaLayout
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: barWindow.width < 1920 ? barWindow.s(8) : barWindow.s(16)
                            
                            MouseArea {
                                id: mediaInfoMouse
                                width: infoLayout.width
                                height: innerMediaLayout.height
                                hoverEnabled: true
                                onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle music"])
                                
                                Row {
                                    id: infoLayout
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: barWindow.s(10)
                                    
                                    scale: mediaInfoMouse.containsMouse ? 1.02 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }

                                    Rectangle {
                                        width: barWindow.s(32); height: barWindow.s(32); radius: barWindow.s(8); color: mocha.surface1
                                        border.width: barWindow.musicData.status === "Playing" ? 1 : 0
                                        border.color: mocha.mauve
                                        clip: true
                                        Image { 
                                            anchors.fill: parent; 
                                            source: barWindow.displayArtUrl || ""; 
                                            fillMode: Image.PreserveAspectCrop 
                                        }
                                        
                                        Rectangle {
                                            anchors.fill: parent
                                            color: Qt.rgba(mocha.mauve.r, mocha.mauve.g, mocha.mauve.b, 0.2)
                                        }
                                    }
                                    Column {
                                        spacing: -2
                                        anchors.verticalCenter: parent.verticalCenter
                                        property real maxColWidth: barWindow.width < 1920 ? barWindow.s(120) : barWindow.s(180)
                                        width: maxColWidth 
                                        
                                        Text { 
                                            text: barWindow.displayTitle; 
                                            font.family: "JetBrains Mono"; 
                                            font.weight: Font.Black; 
                                            font.pixelSize: barWindow.s(13); 
                                            color: mocha.text;
                                            width: parent.width
                                            elide: Text.ElideRight; 
                                        }
                                        Text { 
                                            text: barWindow.displayTime; 
                                            font.family: "JetBrains Mono"; 
                                            font.weight: Font.Black; 
                                            font.pixelSize: barWindow.s(10); 
                                            color: mocha.subtext0;
                                            width: parent.width
                                            elide: Text.ElideRight;
                                        }
                                    }
                                }
                            }

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: barWindow.width < 1920 ? barWindow.s(4) : barWindow.s(8)
                                Item { 
                                    width: barWindow.s(24); height: barWindow.s(24); 
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text { 
                                        anchors.centerIn: parent; text: "󰒮"; font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.s(26); 
                                        color: prevMouse.containsMouse ? mocha.text : mocha.overlay2; 
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        scale: prevMouse.containsMouse ? 1.1 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                                    }
                                    MouseArea { id: prevMouse; hoverEnabled: true; anchors.fill: parent; onClicked: { Quickshell.execDetached(["playerctl", "previous"]); musicForceRefresh.running = true; } } 
                                }
                                Item { 
                                    width: barWindow.s(28); height: barWindow.s(28); 
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text { 
                                        anchors.centerIn: parent; text: barWindow.musicData.status === "Playing" ? "󰏤" : "󰐊"; font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.s(30); 
                                        color: playMouse.containsMouse ? mocha.green : mocha.text; 
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        scale: playMouse.containsMouse ? 1.15 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                                    }
                                    MouseArea { id: playMouse; hoverEnabled: true; anchors.fill: parent; onClicked: { Quickshell.execDetached(["playerctl", "play-pause"]); musicForceRefresh.running = true; } } 
                                }
                                Item { 
                                    width: barWindow.s(24); height: barWindow.s(24); 
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text { 
                                        anchors.centerIn: parent; text: "󰒭"; font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.s(26); 
                                        color: nextMouse.containsMouse ? mocha.text : mocha.overlay2; 
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        scale: nextMouse.containsMouse ? 1.1 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                                    }
                                    MouseArea { id: nextMouse; hoverEnabled: true; anchors.fill: parent; onClicked: { Quickshell.execDetached(["playerctl", "next"]); musicForceRefresh.running = true; } } 
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: centerBox
                    property bool isHovered: centerMouse.containsMouse
                    color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.95) : Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.75)
                    radius: barWindow.s(14); border.width: 1; border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, isHovered ? 0.15 : 0.05)
                    
                    y: (parent.height - barWindow.barHeight) / 2
                    height: 0
                    
                    width: 0
                    visible: false
                    enabled: false
                    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }
                    
                    property real pureCenter: (parent.width - width) / 2
                    property real minCenterDefaultX: mediaBox.defaultX + mediaBox.width + (mediaBox.width > 0 ? barWindow.s(4) : 0)
                    property real defaultX: Math.max(minCenterDefaultX, pureCenter)
                    x: defaultX
                    
                    property bool showLayout: false
                    opacity: showLayout ? 1 : 0
                    transform: Translate {
                        y: centerBox.showLayout ? 0 : barWindow.s(-30)
                        Behavior on y { NumberAnimation { duration: 800; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
                    }

                    Timer {
                        running: barWindow.isStartupReady
                        interval: 150
                        onTriggered: centerBox.showLayout = true
                    }

                    Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

                    scale: isHovered ? 1.03 : 1.0
                    Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutExpo } }
                    Behavior on color { ColorAnimation { duration: 250 } }
                    
                    MouseArea {
                        id: centerMouse
                        anchors.fill: parent
                        hoverEnabled: true
                    }

                    RowLayout {
                        id: centerLayout
                        anchors.centerIn: parent
                        spacing: barWindow.s(24)

                        ColumnLayout {
                            spacing: -2
                            Text { text: barWindow.timeStr; Layout.alignment: Qt.AlignLeft; font.family: "JetBrains Mono"; font.pixelSize: barWindow.s(16); font.weight: Font.Black; color: mocha.blue }
                            Text { text: barWindow.dateStr; Layout.alignment: Qt.AlignLeft; font.family: "JetBrains Mono"; font.pixelSize: barWindow.s(11); font.weight: Font.Bold; color: mocha.subtext0 }
                        }

                        RowLayout {
                            spacing: barWindow.s(8)
                            Text { 
                                text: barWindow.weatherIcon; 
                                Layout.alignment: Qt.AlignVCenter;
                                font.family: "Iosevka Nerd Font"; 
                                font.pixelSize: barWindow.s(24); 
                                color: Qt.tint(barWindow.weatherHex, Qt.rgba(mocha.mauve.r, mocha.mauve.g, mocha.mauve.b, 0.4)) 
                            }
                            Text { 
                                text: barWindow.weatherTemp; 
                                Layout.alignment: Qt.AlignVCenter;
                                font.family: "JetBrains Mono"; 
                                font.pixelSize: barWindow.s(17); 
                                font.weight: Font.Black; 
                                color: mocha.peach 
                            }
                        }
                    }
                }

                Row {
                    id: rightContent
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: barWindow.s(4)
                    
                    property bool showLayout: false
                    opacity: showLayout ? 1 : 0
                    transform: Translate {
                        x: rightContent.showLayout ? 0 : barWindow.s(30)
                        Behavior on x { NumberAnimation { duration: 800; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
                    }
                    
                    Timer {
                        running: barWindow.isStartupReady && barWindow.isDataReady
                        interval: 250
                        onTriggered: rightContent.showLayout = true
                    }

                    Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

                    Rectangle {
                        height: barWindow.barHeight
                        radius: barWindow.s(14)
                        border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)
                        border.width: 1
                        color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.75)
                        
                        property real targetWidth: trayRepeater.count > 0 ? trayLayout.width + barWindow.s(24) : 0
                        width: targetWidth
                        Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }
                        
                        visible: targetWidth > 0
                        opacity: targetWidth > 0 ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 300 } }

                        Row {
                            id: trayLayout
                            anchors.centerIn: parent
                            spacing: barWindow.s(10)

                            Repeater {
                                id: trayRepeater
                                model: SystemTray.items
                                delegate: Image {
                                    id: trayIcon
                                    source: modelData.icon || ""
                                    fillMode: Image.PreserveAspectFit
                                    
                                    sourceSize: Qt.size(barWindow.s(18), barWindow.s(18))
                                    width: barWindow.s(18)
                                    height: barWindow.s(18)
                                    anchors.verticalCenter: parent.verticalCenter
                                    
                                    property bool isHovered: trayMouse.containsMouse
                                    property bool initAnimTrigger: false
                                    opacity: initAnimTrigger ? (isHovered ? 1.0 : 0.8) : 0.0
                                    scale: initAnimTrigger ? (isHovered ? 1.15 : 1.0) : 0.0

                                    Component.onCompleted: {
                                        if (!barWindow.startupCascadeFinished) {
                                            trayAnimTimer.interval = index * 50;
                                            trayAnimTimer.start();
                                        } else {
                                            initAnimTrigger = true;
                                        }
                                    }
                                    Timer {
                                        id: trayAnimTimer
                                        running: false
                                        repeat: false
                                        onTriggered: trayIcon.initAnimTrigger = true
                                    }

                                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

                                    QsMenuAnchor {
                                        id: menuAnchor
                                        anchor.window: barWindow
                                        anchor.item: trayIcon
                                        menu: modelData.menu
                                    }

                                    MouseArea {
                                        id: trayMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                        onClicked: mouse => {
                                            if (mouse.button === Qt.LeftButton) {
                                                if (modelData.isMenuOnly || modelData.onlyMenu) {
                                                    menuAnchor.open();
                                                } else if (typeof modelData.activate === "function") {
                                                    modelData.activate(); 
                                                }
                                            } else if (mouse.button === Qt.MiddleButton) {
                                                if (typeof modelData.secondaryActivate === "function") {
                                                    modelData.secondaryActivate();
                                                }
                                            } else if (mouse.button === Qt.RightButton) {
                                                if (modelData.menu) { 
                                                    menuAnchor.open();
                                                } else if (typeof modelData.contextMenu === "function") {
                                                    modelData.contextMenu(mouse.x, mouse.y);
                                                } else {
                                                    modelData.activate(); 
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

            Rectangle {
                        id: recButton
                        property bool isHovered: recMouse.containsMouse
                        
                        color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.95) : Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.75)
                        radius: barWindow.s(14)
                        border.width: 1
                        border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, isHovered ? 0.15 : 0.05)

                        property real targetWidth: barWindow.isRecording ? barWindow.barHeight : 0
                        width: targetWidth
                        height: barWindow.barHeight 

                        visible: targetWidth > 0 || opacity > 0
                        opacity: barWindow.isRecording ? 1.0 : 0.0
                        clip: true

                        Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
                        Behavior on opacity { NumberAnimation { duration: 300 } }
                        
                        scale: isHovered ? 1.05 : 1.0
                        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                        Behavior on color { ColorAnimation { duration: 200 } }

                        Text {
                            id: recIcon
                            anchors.centerIn: parent
                            text: "" 
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: barWindow.s(20)
                            color: mocha.red
                            
                            SequentialAnimation on opacity {
                                running: barWindow.isRecording && !recButton.isHovered
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.3; duration: 600; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                            }
                            SequentialAnimation on scale {
                                running: barWindow.isRecording && !recButton.isHovered
                                loops: Animation.Infinite
                                NumberAnimation { to: 1.15; duration: 600; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                            }
                        }
                        
                        MouseArea {
                            id: recMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                barWindow.isRecording = false;
                                Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/screenshot.sh"]);
                            }
                        }
                    }

                    Rectangle {
                        id: sidebarButton
                        property bool isHovered: sidebarMouse.containsMouse
                        width: barWindow.barHeight
                        height: barWindow.barHeight
                        radius: barWindow.s(14)
                        border.width: 1
                        border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, isHovered ? 0.15 : 0.08)
                        color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6) : Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.75)
                        Behavior on color { ColorAnimation { duration: 200 } }

                        Text {
                            anchors.centerIn: parent
                            text: "☰"
                            color: sidebarMouse.containsMouse ? mocha.text : mocha.subtext0
                            font.pixelSize: barWindow.s(16)
                            scale: sidebarMouse.pressed ? 0.88 : (sidebarMouse.containsMouse ? 1.06 : 1)
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 140 } }
                        }

                        MouseArea {
                            id: sidebarMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle sidebarcenter"])
                        }
                    }
                }
            }
        }
    }
}
