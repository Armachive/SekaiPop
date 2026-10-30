import QtQuick
import Quickshell
import qs.modules.common

// A slanted progress meter (About / Update's plugin cards, docs/PLUGIN-INSTALL.md): an
// outlined bar leaning like the Settings plates, filled with the accent gradient from the left.
// `value` is 0..1; the fill glides to it.
Item {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    property real value: 0

    implicitWidth: 220
    implicitHeight: 16

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: mt.pSurfaceHover
        border.width: 3
        border.color: mt.pLine
        clip: true
        // A slanted meter. Shear { xFactor } is Qt 6.9+; Debian 13 has Qt 6.8, so the
        // same slant is written as the matrix it is (x' = x + y * -0.25).
        transform: Matrix4x4 {
            matrix: Qt.matrix4x4(1, -0.25, 0, 0,
                                 0, 1, 0, 0,
                                 0, 0, 1, 0,
                                 0, 0, 0, 1)
        }

        Rectangle {
            x: 3
            y: 3
            height: parent.height - 6
            width: Math.max(0, (parent.width - 6) * Math.max(0, Math.min(1, root.value)))
            radius: 3
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: mt.accentMint }
                GradientStop { position: 1; color: mt.accentCyan }
            }
            Behavior on width {
                NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
            }
        }
    }
}
