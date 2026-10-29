import QtQuick
import Quickshell
import qs.modules.common

// A part of a plugin card (About / Update): a dashed rule, then UPDATES / INSTALLED / DIDN'T
// LOAD with a note beside it, and anything declared inside (a key) at the right end.
Item {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    property string title: ""
    property string note: ""
    default property alias content: ends.data

    implicitHeight: 22 + 16 + Math.max(24, ends.height, noteText.implicitHeight) + 8

    Row {
        y: 22
        spacing: 5
        Repeater {
            model: Math.max(0, Math.floor(root.width / 11))
            delegate: Rectangle { width: 6; height: 2.5; color: mt.pSurfaceDivider }
        }
    }

    Row {
        id: words
        y: 22 + 16
        width: root.width - (ends.width > 0 ? ends.width + 14 : 0)
        height: Math.max(24, ends.height)
        spacing: 12

        Text {
            id: titleText
            anchors.verticalCenter: parent.verticalCenter
            text: root.title.toUpperCase()
            color: mt.pInk
            font.family: mt.fontFamily
            font.pixelSize: 13
            font.weight: Font.Black
            font.letterSpacing: 1.6
        }

        Text {
            id: noteText
            anchors.verticalCenter: parent.verticalCenter
            width: words.width - titleText.width - words.spacing
            text: root.note
            wrapMode: Text.WordWrap
            color: mt.pInkSub
            font.family: mt.fontFamily
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }
    }

    Row {
        id: ends
        x: root.width - width
        y: 22 + 16
        spacing: 12
    }
}
