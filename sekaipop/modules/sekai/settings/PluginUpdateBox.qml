import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import "../../common/functions/PluginRepos.js" as PR

// One repository with an update, in the Plugins card's Updates (SettingsPluginsUpdate.qml):
// its name, how many commits, its plugins and the commits it moves between; then Show the
// commits and Update, a meter while it updates, or Updated with Go back once it has.
Item {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    // PluginRepoService.updates' entry ({ key, behind, log, from, to }), or for one just updated
    // { key, behind: 0, log: [] }.
    property var update: null
    // Its plugins' names ("Tailscale"), for the second line.
    property string pluginsText: ""
    property bool open: false

    readonly property var job: root.update ? PluginRepoService.jobs[root.update.key] ?? null : null
    readonly property bool running: !!root.job && root.job.kind === "update" && root.job.state === "running"
    readonly property bool done: !!root.job && root.job.kind === "update" && root.job.state === "done"
    readonly property bool failed: !!root.job && root.job.kind === "update" && root.job.state === "failed"

    implicitHeight: box.height

    Rectangle {
        id: box
        width: parent.width
        height: col.implicitHeight
        radius: 22
        color: mt.pSurface
        border.width: 3
        border.color: mt.pLine
        clip: true

        Column {
            id: col
            width: parent.width

            Item {
                width: parent.width
                height: Math.max(64, head.implicitHeight + 24)

                PluginDiamond {
                    x: 20
                    anchors.verticalCenter: parent.verticalCenter
                    size: 28
                    icon: "inventory_2"
                }

                Column {
                    id: head
                    x: 20 + 28 + 14
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - x - ends.width - 16 - 14
                    spacing: 3

                    Row {
                        spacing: 10

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.update ? root.update.key : ""
                            color: mt.pInk
                            font.family: mt.fontFamily
                            font.pixelSize: 17
                            font.weight: Font.ExtraBold
                        }

                        PluginBadge {
                            visible: !root.done && !!root.update && root.update.behind > 0
                            anchors.verticalCenter: parent.verticalCenter
                            kind: "on"
                            text: root.update ? root.update.behind + (root.update.behind === 1 ? " commit" : " commits") : ""
                        }
                    }

                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: root.failed ? "Didn't update: " + root.job.message
                            : root.pluginsText + (root.update && root.update.from ? "  ·  " + root.update.from + "  →  " + root.update.to : "")
                        color: root.failed ? mt.pInk : mt.pInkSub
                        font.family: mt.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }
                }

                Row {
                    id: ends
                    x: parent.width - width - 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    SettingChip {
                        visible: !root.running && !root.done && !!root.update && root.update.log.length > 0
                        capH: 36
                        fontSize: 14
                        label: root.open ? "Hide the commits" : "Show the commits"
                        icon: root.open ? "expand_less" : "expand_more"
                        onClicked: root.open = !root.open
                    }

                    SettingChip {
                        visible: !root.running && !root.done
                        capH: 36
                        fontSize: 14
                        label: root.failed ? "Try again" : "Update"
                        icon: "download"
                        onClicked: PluginRepoService.update(root.update.key)
                    }

                    Text {
                        visible: root.running
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.job ? root.job.step + "…" : ""
                        color: mt.pInk
                        font.family: mt.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.ExtraBold
                    }

                    PluginMeter {
                        visible: root.running
                        anchors.verticalCenter: parent.verticalCenter
                        value: root.job ? root.job.pct / 100 : 0
                    }

                    PluginBadge {
                        visible: root.done
                        anchors.verticalCenter: parent.verticalCenter
                        kind: "on"
                        icon: "check"
                        text: "Updated"
                    }

                    SettingChip {
                        visible: root.done && !!root.job && root.job.from !== ""
                        capH: 36
                        fontSize: 14
                        label: "Go back to " + (root.job ? root.job.from : "")
                        icon: "undo"
                        onClicked: PluginRepoService.goBack(root.update.key)
                    }
                }
            }

            // the commits it brings: id, subject, age
            Item {
                visible: root.open && !root.done
                width: parent.width
                height: commits.implicitHeight + 24

                Row {
                    spacing: 5
                    Repeater {
                        model: Math.max(0, Math.floor(box.width / 11))
                        delegate: Rectangle { width: 6; height: 2.5; color: mt.pSurfaceDivider }
                    }
                }

                Column {
                    id: commits
                    x: 56
                    y: 10
                    width: parent.width - 56 - 20
                    spacing: 4

                    Repeater {
                        model: root.update ? root.update.log : []

                        delegate: Item {
                            required property var modelData
                            width: commits.width
                            height: 22

                            Text {
                                width: 90
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.hash
                                color: mt.pInkSub
                                font.family: "monospace"
                                font.pixelSize: 13
                            }

                            Text {
                                x: 90 + 14
                                width: parent.width - 90 - 14 - 90 - 14
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                text: modelData.subject
                                color: mt.pInk
                                font.family: mt.fontFamily
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                            }

                            Text {
                                x: parent.width - 90
                                width: 90
                                anchors.verticalCenter: parent.verticalCenter
                                horizontalAlignment: Text.AlignRight
                                text: modelData.age
                                color: mt.pInkSub
                                font.family: mt.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                            }
                        }
                    }
                }
            }
        }
    }
}
