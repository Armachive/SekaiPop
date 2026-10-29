import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import "../../common/functions/PluginRepos.js" as PR

// Removing a repository, second step (SettingsPluginsUpdate.qml): what goes (its plugins, from
// the desktop and the bar; its clone), what to do with their saved settings (kept by default:
// they come back if it is installed again), and the one key that removes it. Esc, or Keep it,
// keeps everything.
Item {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    property string repo: ""
    property var names: []

    signal done()

    property bool deleteSettings: false

    readonly property string clonePath: (PluginRepoService.reposDir !== "" ? PluginRepoService.reposDir : "~/.local/share/sekaipop/plugin-repos") + "/" + root.repo
    readonly property string shortClone: {
        const home = Quickshell.env("HOME") || ""
        return home !== "" && root.clonePath.indexOf(home + "/") === 0 ? "~" + root.clonePath.slice(home.length) : root.clonePath
    }

    implicitHeight: col.implicitHeight + 36

    Component.onCompleted: keyCatcher.forceActiveFocus()

    Item {
        id: keyCatcher
        focus: true
        Keys.onEscapePressed: root.done()
    }

    Rectangle {
        anchors.fill: parent
        radius: 22
        color: mt.pSurfaceHover
        border.width: 3
        border.color: mt.pLine
    }

    Column {
        id: col
        x: 22
        y: 18
        width: root.width - 44
        spacing: 12

        Text {
            text: "Remove " + root.repo + "?"
            color: mt.pInk
            font.family: mt.fontFamily
            font.pixelSize: 19
            font.weight: Font.ExtraBold
        }

        Repeater {
            model: [
                (root.names.length === 1 ? "Its plugin goes: <b>" + root.names[0] + "</b>"
                    : "Its " + root.names.length + " plugins go: " + PR.namesText(root.names.map(n => "<b>" + n + "</b>")))
                    + ", from the desktop and from the bar.",
                "Its clone is deleted: <tt>" + root.shortClone + "</tt>"
            ]

            delegate: Row {
                required property string modelData
                spacing: 10

                Rectangle {
                    y: 9
                    width: 6
                    height: 6
                    radius: 3
                    color: mt.pInk
                }

                Text {
                    width: col.width - 16
                    text: modelData
                    textFormat: Text.StyledText
                    wrapMode: Text.WordWrap
                    color: mt.pInk
                    font.family: mt.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }
            }
        }

        Flow {
            width: parent.width
            spacing: 12

            Text {
                height: 46
                verticalAlignment: Text.AlignVCenter
                text: root.names.length === 1 ? "Its saved settings" : "Their saved settings"
                color: mt.pInk
                font.family: mt.fontFamily
                font.pixelSize: 15
                font.weight: Font.ExtraBold
            }

            SettingChip {
                label: "Keep them"
                selected: !root.deleteSettings
                onClicked: root.deleteSettings = false
            }

            SettingChip {
                label: "Delete them too"
                selected: root.deleteSettings
                onClicked: root.deleteSettings = true
            }
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            textFormat: Text.StyledText
            text: root.deleteSettings
                ? "Deleted, they start over from their defaults if you install it again."
                : "Kept, they come back if you install it again. " + (root.names.length === 1 ? "It is one small file" : "They are " + root.names.length + " small files")
                    + " in <tt>~/.local/state/sekaipop/plugins/</tt>."
            color: mt.pInkSub
            font.family: mt.fontFamily
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

        Row {
            spacing: 14

            SettingChip {
                label: "Keep it"
                onClicked: root.done()
            }

            SettingChip {
                label: "Remove it"
                icon: "delete"
                selected: true
                onClicked: {
                    PluginRepoService.remove(root.repo, root.deleteSettings)
                    root.done()
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Esc keeps everything"
                color: mt.pInkSub
                font.family: mt.fontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
        }
    }
}
