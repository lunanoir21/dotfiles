import QtQuick
import QtQuick.Shapes
import "../core"

// The logo, drawn from the same 100-unit geometry as docs/logo-*.svg.
Item {
    id: root

    property real size: 32
    readonly property real u: root.size / 100

    implicitWidth: root.size
    implicitHeight: root.size

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: DepotTheme.perforation
            strokeWidth: 3 * root.u
            strokeStyle: ShapePath.DashLine
            dashPattern: [1, 2]
            PathAngleArc { centerX: 50 * root.u; centerY: 50 * root.u; radiusX: 44 * root.u; radiusY: 44 * root.u; startAngle: 0; sweepAngle: 360 }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: DepotTheme.tagStroke
            strokeWidth: 5 * root.u
            PathAngleArc { centerX: 50 * root.u; centerY: 50 * root.u; radiusX: 35 * root.u; radiusY: 35 * root.u; startAngle: 0; sweepAngle: 360 }
        }

        ShapePath {
            fillColor: DepotTheme.tagFill
            strokeColor: DepotTheme.tagStroke
            strokeWidth: 2.5 * root.u
            joinStyle: ShapePath.RoundJoin
            startX: 50 * root.u; startY: 32 * root.u
            PathLine { x: 64 * root.u; y: 50 * root.u }
            PathLine { x: 50 * root.u; y: 68 * root.u }
            PathLine { x: 36 * root.u; y: 50 * root.u }
            PathLine { x: 50 * root.u; y: 32 * root.u }
        }
    }

    Rectangle {
        width: 9 * root.u
        height: width
        radius: width / 2
        anchors.centerIn: parent
        color: DepotTheme.accent
    }
}
