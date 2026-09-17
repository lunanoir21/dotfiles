import QtQuick
import "../core"

// The brand mark, played once as a confirmation: a package just got
// "stamped" into the system. Call play() right when an install succeeds.
Item {
    id: root

    property real size: 30

    signal finished()

    implicitWidth: root.size
    implicitHeight: root.size
    opacity: 0
    scale: 0.5
    rotation: -20
    visible: opacity > 0.01

    function play() {
        seq.stop();
        root.opacity = 0;
        root.scale = 1.7;
        root.rotation = -20;
        seq.start();
    }

    DepotSealMark {
        anchors.centerIn: parent
        size: root.size
    }

    SequentialAnimation {
        id: seq
        ParallelAnimation {
            NumberAnimation { target: root; property: "opacity"; to: 1; duration: 130; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "scale"; to: 1; duration: 340; easing.type: Easing.OutBack; easing.overshoot: 2.4 }
            NumberAnimation { target: root; property: "rotation"; to: 0; duration: 340; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
        }
        PauseAnimation { duration: 700 }
        NumberAnimation { target: root; property: "opacity"; to: 0; duration: 260; easing.type: Easing.InCubic }
        ScriptAction { script: root.finished() }
    }
}
