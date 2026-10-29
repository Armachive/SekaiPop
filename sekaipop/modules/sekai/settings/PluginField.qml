import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets

// A text field in the plugin cards (search the reviewed list, type a repository): an icon, the
// text, the card's outline with a pale ring inside and a hard shadow. Enter is `accepted`.
Item {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    property string icon: "search"
    property string placeholder: ""
    property alias text: input.text
    readonly property bool focused: input.activeFocus

    signal accepted()

    implicitHeight: 50 + 4

    Rectangle {
        y: 4
        width: parent.width
        height: 50
        radius: 16
        color: mt.pLineShadow
    }

    Rectangle {
        width: parent.width
        height: 50
        radius: 16
        color: mt.pSurface
        border.width: 3
        border.color: input.activeFocus ? mt.accentCyan : mt.pLine

        Rectangle {
            anchors.fill: parent
            anchors.margins: 3
            radius: 13
            color: "transparent"
            border.width: 4
            border.color: mt.pSurfaceRing
        }

        MaterialIcon {
            x: 16
            anchors.verticalCenter: parent.verticalCenter
            size: 19
            name: root.icon
            color: mt.pInkSub
        }

        TextInput {
            id: input
            x: 16 + 19 + 12
            width: parent.width - x - 16
            anchors.verticalCenter: parent.verticalCenter
            clip: true
            color: mt.pInk
            selectionColor: mt.accentCyan
            font.family: mt.fontFamily
            font.pixelSize: 16
            font.weight: Font.Bold
            onAccepted: root.accepted()
            Keys.onEscapePressed: event => {
                if (input.text !== "") {
                    input.text = ""
                    event.accepted = true
                } else {
                    event.accepted = false
                }
            }

            Text {
                visible: input.text === ""
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                elide: Text.ElideRight
                text: root.placeholder
                color: mt.pInkSub
                font: input.font
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            acceptedButtons: Qt.NoButton
        }
    }
}
