import QtQuick
import QtQuick.Shapes
import "../core"

// A perforation line — the same dashed stroke as the seal mark, reused as a
// structural motif: the tear between a manifest tag's icon and its label.
Shape {
    id: root

    property color tone: DepotTheme.perforation

    implicitHeight: 1
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: "transparent"
        strokeColor: root.tone
        strokeWidth: 1.4
        strokeStyle: ShapePath.DashLine
        dashPattern: [1, 1.6]
        startX: 0; startY: 0.5
        PathLine { x: root.width; y: 0.5 }
    }
}
