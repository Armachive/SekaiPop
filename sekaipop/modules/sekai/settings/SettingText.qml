import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets

// A line of text to type, in the Settings Panel's style: a name on the left and a
// keycap-like field to its right, full width of its row. Enter (or leaving the
// field) sends `submitted`; the button on the right sends `cleared` (when
// `clearable`). Escape puts the old text back.
//
//   SettingText {
//       label: "Location"
//       sublabel: "Type your city"
//       value: SettingsService.get("weather.location")
//       placeholder: "automatic (from your IP)"
//       onSubmitted: text => SettingsService.set("weather.location", text)
//   }
Item {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    property string label: ""
    property string sublabel: ""
    property string value: ""
    property string placeholder: ""
    property bool clearable: true
    property real labelWidth: 196

    signal submitted(string text)
    signal cleared()
    // Every keystroke, for a field that searches as you type (App fonts).
    signal edited(string text)

    // Back to `value`, and the keyboard let go, without sending `submitted`: for a field
    // whose choice was made somewhere else (a match picked under it).
    function reset() {
        input.text = root.value
        input.focus = false
    }

    width: parent ? parent.width : 600
    height: Math.max(labelColumn.implicitHeight, 58)

    Column {
        id: labelColumn
        y: Math.max(0, (root.height - implicitHeight) / 2)
        width: Math.max(0, root.labelWidth - 14)
        spacing: 2

        Text {
            width: parent.width
            text: root.label
            color: mt.pInk
            font.family: mt.fontFamily
            font.pixelSize: 18
            font.weight: Font.ExtraBold
            font.styleName: mt.fontStyleBold
            wrapMode: Text.WordWrap
        }
        Text {
            visible: root.sublabel !== ""
            width: parent.width
            text: root.sublabel
            color: mt.pInkSub
            font.family: mt.fontFamily
            font.pixelSize: 14
            wrapMode: Text.WordWrap
        }
    }

    // The field: the Pill look (outline, hard shadow) the rest of the panel uses.
    Pill {
        id: field
        x: root.labelWidth
        y: Math.max(0, (root.height - height) / 2)
        width: root.width - root.labelWidth - (root.clearable ? 58 : 0)
        height: 46 + mt.shadowOffset
        cornerRadius: 16
        ringWidth: 4
        fillColor: mt.pSurface

        MouseArea {
            anchors.fill: parent
            onPressed: input.forceActiveFocus()
        }

        TextInput {
            id: input
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            clip: true
            selectByMouse: true
            text: root.value
            color: mt.pInk
            selectionColor: mt.accentCyan
            selectedTextColor: mt.colBorder
            font.family: mt.fontFamily
            font.pixelSize: 17
            font.weight: Font.DemiBold

            onTextEdited: root.edited(input.text)
            onAccepted: {
                root.submitted(input.text.trim())
                input.focus = false
            }
            Keys.onEscapePressed: {
                input.text = root.value
                input.focus = false
            }
            onActiveFocusChanged: {
                if (!activeFocus && input.text.trim() !== root.value)
                    root.submitted(input.text.trim())
            }

            Text {
                visible: input.text === "" && !input.activeFocus
                anchors.verticalCenter: parent.verticalCenter
                text: root.placeholder
                color: mt.pInkSub
                font: input.font
            }
        }
    }

    // Back to the default (empty).
    SettingRoundButton {
        visible: root.clearable
        x: field.x + field.width + 12
        y: Math.max(0, (root.height - height) / 2)
        icon: "close"
        enabled: root.value !== ""
        opacity: enabled ? 1 : 0.4
        onClicked: {
            input.text = ""
            root.cleared()
        }
    }

    // The saved value changed from elsewhere.
    onValueChanged: if (!input.activeFocus) input.text = root.value
}
