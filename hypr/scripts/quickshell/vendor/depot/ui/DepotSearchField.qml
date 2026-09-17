import QtQuick
import QtQuick.Shapes
import "../core"

Item {
    id: root

    property alias text: input.text
    property string placeholder: ""

    signal escaped()

    function focusInput() {
        input.forceActiveFocus();
        input.selectAll();
    }

    function deselect() {
        input.deselect();
        input.cursorPosition = input.text.length;
    }

    implicitHeight: 46

    Rectangle {
        anchors.fill: parent
        radius: DepotTheme.radiusMedium
        color: DepotTheme.surface0
        border.width: 1
        border.color: input.activeFocus ? DepotTheme.overlay0 : DepotTheme.line

        Behavior on border.color { ColorAnimation { duration: 120 } }
    }

    // Magnifier, drawn so no icon font is needed.
    Shape {
        id: glass
        width: 16
        height: 16
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: input.activeFocus ? DepotTheme.text : DepotTheme.overlay0
            strokeWidth: 1.8
            capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: 6.5; centerY: 6.5; radiusX: 5.2; radiusY: 5.2; startAngle: 0; sweepAngle: 360 }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: input.activeFocus ? DepotTheme.text : DepotTheme.overlay0
            strokeWidth: 1.8
            capStyle: ShapePath.RoundCap
            startX: 10.6; startY: 10.6
            PathLine { x: 15; y: 15 }
        }
    }

    TextInput {
        id: input
        anchors.left: glass.right
        anchors.leftMargin: 12
        anchors.right: clear.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        color: DepotTheme.text
        selectionColor: DepotTheme.alpha(DepotTheme.accent, 0.35)
        selectedTextColor: DepotTheme.text
        font.family: DepotTheme.sans
        font.pixelSize: 15
        clip: true
        maximumLength: 80
        Keys.onEscapePressed: event => {
            if (input.text !== "") input.text = "";
            else root.escaped();
            event.accepted = true;
        }

        Text {
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            text: root.placeholder
            color: DepotTheme.overlay0
            font: input.font
            visible: input.text === ""
            elide: Text.ElideRight
        }
    }

    Item {
        id: clear
        width: input.text === "" ? 0 : 32
        height: 32
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        visible: input.text !== ""

        Rectangle {
            anchors.fill: parent
            radius: DepotTheme.radiusSmall
            color: clearMouse.containsMouse ? DepotTheme.surface1 : "transparent"
        }

        Shape {
            width: 10
            height: 10
            anchors.centerIn: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: DepotTheme.subtext0
                strokeWidth: 1.6
                capStyle: ShapePath.RoundCap
                fillColor: "transparent"
                startX: 0; startY: 0
                PathLine { x: 10; y: 10 }
                PathMove { x: 10; y: 0 }
                PathLine { x: 0; y: 10 }
            }
        }

        MouseArea {
            id: clearMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                input.text = "";
                input.forceActiveFocus();
            }
        }
    }
}
