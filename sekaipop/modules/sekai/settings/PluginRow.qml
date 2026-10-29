import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import "../../common/functions/PluginForm.js" as PF
import "../../common/functions/PluginRepos.js" as PR

// One plugin in the Plugins card's list (SettingsPluginsCard.qml): its icon, name, version
// and id, its description, whether it is on the desktop (and on which monitors), a warning
// when a secret is missing, and the key that opens it.
//
// With `skip` set (a PluginService.skipped entry) it is a folder that did not load instead:
// dashed, SKIPPED, what is wrong in plain words (PluginForm.skipInfo), who has to fix it, the
// shell's own message for a bug report, and the one thing the card can do about it.
Item {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    property var pst: null              // its PluginState (a plugin that loaded)
    property var skip: null             // or { id, error, code, field } (one that did not)

    signal openRequested()
    signal actionRequested(string action)
    // "Update in About": its repository has commits to bring (About / Update's Plugins card).
    signal aboutRequested()

    readonly property bool skipped: skip !== null
    readonly property var plugin: pst ? pst.plugin : null
    readonly property var why: skipped ? PF.skipInfo(skip) : null
    readonly property var monitors: {
        const _ = [WidgetClones.spots, pst ? pst.shown : false, pst ? pst.screenName : ""]
        return pst ? PluginService.monitorsOf(pst.pluginId) : []
    }
    readonly property string warn: plugin ? PF.warnText(plugin, pst.secretSources) : ""
    readonly property bool hovered: area.containsMouse || key.hovered

    // Where it came from (PluginRepos.repoOf): a repository the shell installed, a folder of the
    // user's own, or one copied in by hand. Updating it is in About / Update, not here.
    readonly property var origin: plugin ? PR.repoOf(plugin.target || "", PluginRepoService.reposDir, PluginRepoService.lock) : null
    readonly property var repoInfo: origin && origin.kind === "repo" ? PluginRepoService.lock.repos[origin.repo] ?? null : null
    readonly property int behind: {
        if (!origin || origin.kind !== "repo")
            return 0
        const c = PluginRepoService.checkResult[origin.repo]
        return c && c.status === "ok" && !(repoInfo && repoInfo.pinned) ? c.behind : 0
    }

    implicitHeight: Math.max(46 + 32, main.implicitHeight + 32)

    // hover, on a plugin; a dashed outline on a skipped one
    Rectangle {
        anchors.fill: parent
        radius: 20
        color: mt.pSurfaceHover
        opacity: root.hovered && !root.skipped ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: 90 }
        }
    }

    Canvas {
        id: dashes
        visible: root.skipped
        anchors.fill: parent
        onPaint: {
            const c = getContext("2d")
            c.reset()
            c.strokeStyle = mt.pLine
            c.lineWidth = 3
            c.setLineDash([3, 2])
            c.beginPath()
            c.roundedRect(1.5, 1.5, width - 3, height - 3, 20, 20)
            c.stroke()
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
            target: root.mt
            function onPLineChanged() { dashes.requestPaint() }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.skipped ? Qt.ArrowCursor : Qt.PointingHandCursor
        onClicked: if (!root.skipped) root.openRequested()
    }

    PluginDiamond {
        x: 22 + 4
        y: root.skipped ? 16 + 6 : (root.height - height) / 2
        opacity: root.skipped ? 0.55 : 1
        icon: root.skipped ? "extension_off" : root.plugin ? root.plugin.icon : "extension"
    }

    Column {
        id: main
        x: 22 + 4 + 46 + 4 + 20
        y: 16
        width: root.width - x - ends.width - 20 - 16
        spacing: 5

        // name, version, id (or the folder, SKIPPED)
        Flow {
            width: parent.width
            spacing: 10

            Text {
                height: 26
                verticalAlignment: Text.AlignVCenter
                text: root.skipped ? root.skip.id : root.plugin ? root.plugin.name : ""
                color: mt.pInk
                font.family: mt.fontFamily
                font.pixelSize: 19
                font.weight: Font.Black
            }

            PluginBadge {
                y: 1
                kind: root.skipped ? "tag" : "ver"
                text: root.skipped ? "SKIPPED" : root.plugin ? root.plugin.version : ""
            }

            Text {
                height: 26
                verticalAlignment: Text.AlignVCenter
                text: root.skipped ? "not loaded" : root.plugin ? root.plugin.id : ""
                color: mt.pInkSub
                font.family: root.skipped ? mt.fontFamily : "monospace"
                font.pixelSize: root.skipped ? 15 : 13
                font.weight: Font.Bold
            }

            PluginBadge {
                visible: root.behind > 0
                y: 1
                kind: "on"
                text: root.behind + (root.behind === 1 ? " commit behind" : " commits behind")
            }
        }

        Text {
            visible: text !== ""
            width: parent.width
            text: root.skipped ? root.why.reason : root.plugin ? root.plugin.description : ""
            wrapMode: Text.WordWrap
            color: root.skipped ? mt.pInk : mt.pInkSub
            font.family: mt.fontFamily
            font.pixelSize: root.skipped ? 17 : 15
            font.weight: Font.Bold
        }

        // where it is, and what is missing
        Flow {
            visible: !root.skipped
            width: parent.width
            topPadding: 3
            spacing: 8

            PluginBadge {
                readonly property bool inBar: !!root.pst && root.pst.barShown
                visible: !!root.pst && !!root.pst.plugin.bar
                kind: inBar ? "on" : "mute"
                icon: inBar ? "check" : ""
                text: inBar ? "In the bar" : "Not in the bar · turn it on in Settings > Bar"
            }

            PluginBadge {
                visible: !root.pst || root.pst.plugin.files.widget
                kind: root.monitors.length > 0 ? "on" : "mute"
                icon: root.monitors.length > 0 ? "check" : ""
                text: root.monitors.length > 0 ? "On the desktop" : "Not on the desktop · add it in Edit Desktop"
            }

            Repeater {
                model: root.monitors

                delegate: PluginBadge {
                    required property var modelData
                    kind: "cap"
                    text: modelData
                }
            }

            PluginBadge {
                visible: root.warn !== ""
                kind: "warn"
                icon: "error"
                text: root.warn
            }
        }

        // where it came from
        Flow {
            visible: !root.skipped && !!root.origin && root.origin.kind !== "copied"
            width: parent.width
            spacing: 8

            MaterialIcon {
                y: 1
                size: 15
                name: root.origin && root.origin.kind === "repo" ? "inventory_2" : "folder_special"
                color: mt.pInkSub
            }

            Text {
                text: root.origin && root.origin.kind === "repo" ? "From" : "Managed by you:"
                color: mt.pInkSub
                font.family: mt.fontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

            Text {
                text: !root.origin ? "" : root.origin.kind === "repo" ? root.origin.repo
                    : PR.sourceLine("yours", "", false, root.origin.path, Quickshell.env("HOME") || "").code
                color: mt.pInk
                font.family: "monospace"
                font.pixelSize: 13
            }

            Text {
                visible: !!root.origin && root.origin.kind === "repo"
                text: "· updates, going back and removing are in About › Update"
                color: mt.pInkSub
                font.family: mt.fontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
        }

        // a skipped folder: who fixes it, and the shell's own words
        Row {
            visible: root.skipped
            spacing: 8

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                size: 17
                name: "build"
                color: mt.pInk
            }

            Text {
                text: root.skipped ? root.why.fix : ""
                color: mt.pInk
                font.family: mt.fontFamily
                font.pixelSize: 15
                font.weight: Font.Black
            }
        }

        // kept word for word, for a bug report
        Flow {
            visible: root.skipped
            width: parent.width
            spacing: 6

            Text {
                text: "The shell said:"
                color: mt.pInkSub
                font.family: mt.fontFamily
                font.pixelSize: 13
                font.weight: Font.Bold
            }

            Text {
                width: Math.min(implicitWidth, parent.width)
                text: root.skipped ? root.skip.error : ""
                wrapMode: Text.WrapAnywhere
                color: mt.pInkSub
                font.family: "monospace"
                font.pixelSize: 13
            }
        }
    }

    Row {
        id: ends
        x: root.width - width - 16
        y: root.skipped ? 16 : (root.height - height) / 2
        spacing: 14

        Text {
            visible: !root.skipped
            anchors.verticalCenter: parent.verticalCenter
            text: root.plugin ? PF.countText(root.plugin) : ""
            color: mt.pInkSub
            font.family: mt.fontFamily
            font.pixelSize: 14
            font.weight: Font.ExtraBold
        }

        SettingChip {
            visible: !root.skipped && root.behind > 0
            capH: 36
            fontSize: 14
            label: "Update in About"
            icon: "update"
            onClicked: root.aboutRequested()
        }

        SettingChip {
            id: key
            capH: 36
            fontSize: 14
            label: root.skipped ? (root.why.action === "update" ? "Check for updates" : "Open its folder")
                : root.plugin && PF.hasForm(root.plugin) ? "Settings" : "Details"
            icon: root.skipped ? "" : "expand_more"
            onClicked: {
                if (root.skipped)
                    root.actionRequested(root.why.action)
                else
                    root.openRequested()
            }
        }
    }
}
