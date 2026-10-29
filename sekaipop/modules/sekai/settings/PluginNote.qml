import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets

// A note in the plugin cards: `warn` is the one that wants reading before acting (the
// not-reviewed sentence: the happy-yellow attribute colour, as the warn badge), `cool` the
// quiet one (offline, installed, failed: the hover tint in a dashed outline). Anything
// declared inside (keys) goes under the words.
Item {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    property string kind: "cool"
    property string icon: "info"
    // Rich text: <b> for the sentence that matters.
    property string text: ""

    default property alias content: keys.data

    readonly property bool warn: root.kind === "warn"

    implicitHeight: col.implicitHeight + 24

    Rectangle {
        anchors.fill: parent
        visible: root.warn
        radius: 16
        color: mt.attributeColors[2]
        border.width: 3
        border.color: mt.pLine
    }

    Rectangle {
        anchors.fill: parent
        visible: !root.warn
        radius: 16
        color: mt.pSurfaceHover
    }

    Canvas {
        id: dashes
        visible: !root.warn
        anchors.fill: parent
        onPaint: {
            const c = getContext("2d")
            c.reset()
            c.strokeStyle = mt.pLine
            c.lineWidth = 3
            c.setLineDash([3, 2])
            c.beginPath()
            c.roundedRect(1.5, 1.5, width - 3, height - 3, 16, 16)
            c.stroke()
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    MaterialIcon {
        x: 16
        y: 13
        size: 19
        name: root.icon
        color: root.warn ? mt.colBorder : mt.pInk
    }

    Column {
        id: col
        x: 16 + 19 + 10
        y: 12
        width: root.width - x - 16
        spacing: 10

        Text {
            width: parent.width
            text: root.text
            textFormat: Text.StyledText
            wrapMode: Text.WordWrap
            color: root.warn ? mt.colBorder : mt.pInk
            font.family: mt.fontFamily
            font.pixelSize: 15
            font.weight: Font.Bold
            lineHeight: 1.2
        }

        Flow {
            id: keys
            visible: children.length > 0
            width: parent.width
            spacing: 10
        }
    }
}
