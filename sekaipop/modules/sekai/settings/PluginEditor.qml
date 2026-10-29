import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import "../../common/functions/PluginForm.js" as PF

// An open plugin on the Plugins card (SettingsPluginsCard.qml), in its row's place: a header
// on the accent gradient (icon, name, version, id, Close), where it is (its folder, the
// monitors it is on), its settings as a form built from the manifest (PluginForm.form), and
// its secrets, said found or not and never shown.
//
// Every change is saved at once (PluginState.setSetting) and the widget, bound to its
// settings, redraws as you go.
Item {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    property var pst: null              // its PluginState
    readonly property var plugin: pst ? pst.plugin : null

    signal closeRequested()
    signal placeRequested()

    // The form's shape from the manifest alone, so a change of value doesn't rebuild the rows
    // (a slider would be destroyed under the pointer); each row reads its values itself.
    readonly property var groups: plugin ? PF.form(plugin, plugin.settings).map(g => ({ title: g.title, keys: g.rows.map(r => r.key) })) : []
    readonly property int changedCount: plugin ? PF.changedKeys(plugin, pst.settings).length : 0
    readonly property var secretNames: plugin ? Object.keys(plugin.secrets) : []
    readonly property var monitors: {
        // read here so the binding follows them (monitorsOf reads them through the service)
        const _ = [WidgetClones.spots, pst ? pst.shown : false, pst ? pst.screenName : ""]
        return pst ? PluginService.monitorsOf(pst.pluginId) : []
    }
    readonly property string folderShown: {
        const home = Quickshell.env("HOME") || ""
        const d = pst ? pst.dir : ""
        return home !== "" && d.indexOf(home + "/") === 0 ? "~" + d.slice(home.length) : d
    }

    implicitHeight: frame.height + 6

    // the hard shadow
    Rectangle {
        x: 5
        y: 4
        width: frame.width
        height: frame.height
        radius: 24
        color: mt.pLineShadow
    }

    Rectangle {
        id: frame
        width: root.width - 5
        height: body.y + body.implicitHeight
        radius: 24
        color: mt.pSurface
        border.width: 4
        border.color: mt.pLine
        clip: true

        // ----- the header -----
        Rectangle {
            id: head
            x: 4
            y: 4
            width: parent.width - 8
            height: 70
            topLeftRadius: 20
            topRightRadius: 20
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: mt.accentCyan }
                GradientStop { position: 1; color: mt.accentMint }
            }

            // the white ring inside the gradient
            Rectangle {
                anchors.fill: parent
                topLeftRadius: 20
                topRightRadius: 20
                color: "transparent"
                border.width: 5
                border.color: mt.pSurfaceRing
            }

            Row {
                x: 20
                anchors.verticalCenter: parent.verticalCenter
                spacing: 16

                PluginDiamond {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: root.plugin ? root.plugin.icon : "extension"
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.plugin ? root.plugin.name : ""
                    color: mt.colBorder
                    font.family: mt.fontFamily
                    font.pixelSize: 21
                    font.weight: Font.Black
                }

                PluginBadge {
                    anchors.verticalCenter: parent.verticalCenter
                    kind: "ver"
                    onAccent: true
                    text: root.plugin ? root.plugin.version : ""
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.plugin ? root.plugin.id : ""
                    color: mt.colBorder
                    font.family: "monospace"
                    font.pixelSize: 13
                }
            }

            SettingChip {
                x: parent.width - width - 14
                anchors.verticalCenter: parent.verticalCenter
                capH: 36
                fontSize: 14
                label: "Close"
                icon: "expand_less"
                onClicked: root.closeRequested()
            }
        }

        Column {
            id: body
            x: 28
            y: head.y + head.height
            width: parent.width - 56
            topPadding: 20
            bottomPadding: 26
            spacing: 6

            // ----- where it is -----
            Item {
                width: parent.width
                height: meta.height + 16 + 3

                Flow {
                    id: meta
                    width: parent.width - (placeChip.visible ? placeChip.width + 22 : 0)
                    spacing: 22

                    Row {
                        height: 32
                        spacing: 8

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            size: 17
                            name: "folder"
                            color: mt.pInkSub
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.folderShown
                            color: mt.pInkSub
                            font.family: "monospace"
                            font.pixelSize: 13
                        }
                    }

                    Row {
                        height: 32
                        spacing: 8

                        // A plugin with a bar entry (docs/PLUGINS.md): whether it is on the bar.
                        PluginBadge {
                            readonly property bool inBar: !!root.pst && root.pst.barShown
                            visible: !!root.plugin && !!root.plugin.bar
                            anchors.verticalCenter: parent.verticalCenter
                            kind: inBar ? "on" : "mute"
                            icon: inBar ? "check" : ""
                            text: inBar ? "In the bar" : "Not in the bar"
                        }

                        PluginBadge {
                            visible: !root.plugin || root.plugin.files.widget
                            anchors.verticalCenter: parent.verticalCenter
                            kind: root.monitors.length > 0 ? "on" : "mute"
                            icon: root.monitors.length > 0 ? "check" : ""
                            text: root.monitors.length > 0 ? "On the desktop" : "Not on the desktop"
                        }

                        Repeater {
                            model: root.monitors

                            delegate: PluginBadge {
                                required property var modelData
                                anchors.verticalCenter: parent.verticalCenter
                                kind: "cap"
                                text: modelData
                            }
                        }
                    }
                }

                SettingChip {
                    id: placeChip
                    // Only a plugin with a desktop widget has something to place.
                    visible: !root.plugin || root.plugin.files.widget
                    x: parent.width - width
                    capH: 36
                    fontSize: 14
                    label: "Place it in Edit Desktop"
                    onClicked: root.placeRequested()
                }

                // the dashed line under it
                Row {
                    y: parent.height - 3
                    spacing: 5
                    Repeater {
                        model: Math.max(0, Math.floor(body.width / 11))
                        delegate: Rectangle { width: 6; height: 2.5; color: mt.pSurfaceDivider }
                    }
                }
            }

            // ----- settings -----
            PluginSectionHead {
                visible: root.plugin !== null && Object.keys(root.plugin.settings).length > 0
                width: parent.width
                title: "Settings"
                note: "Saved as you change them."
                action: root.changedCount > 0 ? "Reset all " + root.changedCount + " changed" : ""
                actionIcon: "restart_alt"
                onActivated: root.pst.resetAll()
            }

            Repeater {
                model: root.groups

                delegate: Column {
                    id: grp
                    required property var modelData
                    width: body.width

                    Text {
                        visible: grp.modelData.title !== ""
                        topPadding: 14
                        bottomPadding: 2
                        text: grp.modelData.title.toUpperCase()
                        color: mt.pInkSub
                        font.family: mt.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Black
                        font.letterSpacing: 1.4
                    }

                    Repeater {
                        model: grp.modelData.keys

                        delegate: PluginSettingRow {
                            required property var modelData
                            width: body.width
                            row: PF.row(root.plugin, root.pst.settings, modelData)
                            onEdited: value => root.pst.setSetting(modelData, value)
                            onResetRequested: root.pst.resetSetting(modelData)
                        }
                    }
                }
            }

            // ----- secrets -----
            PluginSectionHead {
                visible: root.secretNames.length > 0
                width: parent.width
                title: "Secrets"
                note: "Never shown here and never saved by the shell. Read when the plugin starts."
                action: "Reload"
                actionIcon: "refresh"
                onActivated: root.pst.reloadSecrets()
            }

            Repeater {
                model: root.secretNames

                delegate: PluginSecretRow {
                    required property var modelData
                    width: body.width
                    info: PF.secretInfo(modelData, root.plugin.secrets[modelData], root.pst.secretSources[modelData] || "")
                }
            }
        }
    }
}
