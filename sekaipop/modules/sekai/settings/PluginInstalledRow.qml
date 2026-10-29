import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import "../../common/functions/PluginRepos.js" as PR

// One installed plugin in About / Update's Plugins card (SettingsPluginsUpdate.qml): its icon,
// name, version and id, a badge or two (commits behind, pinned), where it came from, where it
// is (the bar, the desktop), and one key at the end (Source, Open the folder).
//
// `indent` is a plugin under its repository's own row (a repository with several plugins).
Item {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    property var pst: null              // its PluginState
    property var source: null           // PR.sourceLine(), or null for none (under its repository)
    property var badges: []             // [{ kind, text, icon }] (PluginBadge's)
    property string keyLabel: ""
    property string keyIcon: ""
    property bool indent: false
    property bool selected: false

    signal keyClicked()

    readonly property var plugin: pst ? pst.plugin : null
    readonly property var monitors: {
        const _ = [WidgetClones.spots, pst ? pst.shown : false, pst ? pst.screenName : ""]
        return pst ? PluginService.monitorsOf(pst.pluginId) : []
    }

    readonly property real inset: root.indent ? 34 : 0

    implicitHeight: main.implicitHeight + (root.indent ? 16 : 24)

    Rectangle {
        x: root.inset
        width: root.width - root.inset
        height: root.height
        radius: 20
        color: mt.pSurfaceHover
        opacity: root.selected || area.containsMouse ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: 90 }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    PluginDiamond {
        x: root.inset + 20
        anchors.verticalCenter: parent.verticalCenter
        size: root.indent ? 34 : 46
        icon: root.plugin ? root.plugin.icon : "extension"
    }

    Column {
        id: main
        x: root.inset + 20 + (root.indent ? 34 : 46) + 18
        y: root.indent ? 8 : 12
        width: root.width - x - ends.width - 14 - 18
        spacing: 4

        Flow {
            width: parent.width
            spacing: 10

            Text {
                height: 28
                verticalAlignment: Text.AlignVCenter
                text: root.plugin ? root.plugin.name : ""
                color: mt.pInk
                font.family: mt.fontFamily
                font.pixelSize: 18
                font.weight: Font.ExtraBold
            }

            PluginBadge {
                y: 2
                kind: "ver"
                text: root.plugin ? root.plugin.version : ""
            }

            Text {
                height: 28
                verticalAlignment: Text.AlignVCenter
                text: root.plugin ? root.plugin.id : ""
                color: mt.pInkSub
                font.family: "monospace"
                font.pixelSize: 13
            }

            Repeater {
                model: root.badges

                delegate: PluginBadge {
                    required property var modelData
                    kind: modelData.kind
                    icon: modelData.icon || ""
                    text: modelData.text
                }
            }
        }

        // where it came from
        Flow {
            visible: root.source !== null
            width: parent.width
            spacing: 8

            MaterialIcon {
                y: 1
                size: 15
                name: root.source ? root.source.icon : ""
                color: mt.pInkSub
            }

            Text {
                text: root.source ? root.source.text : ""
                color: mt.pInkSub
                font.family: mt.fontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

            Text {
                visible: text !== ""
                text: root.source ? root.source.code : ""
                color: mt.pInk
                font.family: "monospace"
                font.pixelSize: 13
            }

            Text {
                visible: text !== ""
                text: root.source && root.source.note !== "" ? "· " + root.source.note : ""
                color: mt.pInkSub
                font.family: mt.fontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
        }

        // where it is
        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: root.plugin ? PR.whereText(root.plugin, root.pst.barShown, root.monitors) : ""
            color: mt.pInkSub
            font.family: mt.fontFamily
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }
    }

    Row {
        id: ends
        x: root.width - width - 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        SettingChip {
            visible: root.keyLabel !== ""
            capH: 36
            fontSize: 14
            label: root.keyLabel
            icon: root.keyIcon
            onClicked: root.keyClicked()
        }
    }
}
