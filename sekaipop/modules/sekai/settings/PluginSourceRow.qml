import QtQuick
import Quickshell
import qs.modules.common

// One row of an opened repository (PluginSourcePanel.qml): what it is, its value, and an
// optional key at the end (Go back, Pin here, Remove…).
Item {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    property string label: ""
    property string text: ""
    property string key: ""
    property string keyIcon: ""
    property bool busy: false

    signal keyClicked()

    height: Math.max(52, valueText.implicitHeight + 16)

    Text {
        width: 220
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        color: mt.pInk
        font.family: mt.fontFamily
        font.pixelSize: 15
        font.weight: Font.ExtraBold
    }

    Text {
        id: valueText
        x: 220 + 18
        width: root.width - x - (chip.visible ? chip.width + 18 : 0)
        anchors.verticalCenter: parent.verticalCenter
        wrapMode: Text.WordWrap
        text: root.text
        color: mt.pInk
        font.family: mt.fontFamily
        font.pixelSize: 15
        font.weight: Font.DemiBold
    }

    SettingChip {
        id: chip
        visible: root.key !== ""
        x: root.width - width
        anchors.verticalCenter: parent.verticalCenter
        capH: 36
        fontSize: 14
        label: root.busy ? "…" : root.key
        icon: root.keyIcon
        onClicked: if (!root.busy) root.keyClicked()
    }
}
