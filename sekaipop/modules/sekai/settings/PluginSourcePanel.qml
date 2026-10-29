import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import "../../common/functions/PluginRepos.js" as PR

// A repository opened in the Plugins card (SettingsPluginsUpdate.qml): where it came from,
// the commit it is on, the one before its last update (Go back), Pin, and Remove. Drawn like
// an open plugin in Desktop › Plugins (PluginEditor.qml): the accent header, then the rows.
Item {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    property string repo: ""
    // Its plugins' states (one or several).
    property var states: []

    signal closeRequested()
    signal removeRequested()

    readonly property var info: PluginRepoService.lock.repos[root.repo] ?? null
    readonly property var one: root.states.length === 1 ? root.states[0] : null
    readonly property bool github: PR.REPO_RE.test(root.repo)
    readonly property var job: PluginRepoService.jobs[root.repo] ?? null

    function when(ms) {
        if (!ms)
            return ""
        const d = new Date(ms)
        const today = new Date()
        return d.toDateString() === today.toDateString()
            ? "today at " + Qt.formatTime(d, "hh:mm")
            : Qt.formatDate(d, "d MMM")
    }

    implicitHeight: frame.height + 6

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
                width: parent.width - 20 - keys.width - 28
                spacing: 16
                clip: true

                PluginDiamond {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: root.one ? root.one.plugin.icon : "inventory_2"
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.one ? root.one.plugin.name : root.repo
                    color: mt.colBorder
                    font.family: mt.fontFamily
                    font.pixelSize: 21
                    font.weight: Font.Black
                }

                PluginBadge {
                    visible: root.one !== null
                    anchors.verticalCenter: parent.verticalCenter
                    kind: "ver"
                    onAccent: true
                    text: root.one ? root.one.plugin.version : ""
                }

                Text {
                    visible: root.one !== null
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.repo
                    color: mt.colBorder
                    font.family: "monospace"
                    font.pixelSize: 13
                }
            }

            Row {
                id: keys
                x: parent.width - width - 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                SettingChip {
                    visible: root.one !== null
                    capH: 36
                    fontSize: 14
                    label: "Settings"
                    icon: "tune"
                    onClicked: PluginService.askSettings(root.one.pluginId, QsWindow.window && QsWindow.window.screen ? QsWindow.window.screen.name : "")
                }

                SettingChip {
                    capH: 36
                    fontSize: 14
                    label: "Close"
                    icon: "expand_less"
                    onClicked: root.closeRequested()
                }
            }
        }

        Column {
            id: body
            x: 28
            y: head.y + head.height
            width: parent.width - 56
            topPadding: 6
            bottomPadding: 24
            spacing: 6

            PluginRepoHead {
                width: parent.width
                title: "Source"
                note: "Where it came from, and where it can go back to."
            }

            PluginSourceRow {
                width: body.width
                label: "Repository"
                text: root.repo + (root.info && root.info.reviewed ? " · reviewed" : " · not reviewed")
                key: root.github ? "On GitHub" : ""
                keyIcon: "open_in_new"
                onKeyClicked: Qt.openUrlExternally("https://github.com/" + root.repo)
            }

            PluginSourceRow {
                width: body.width
                label: "On commit"
                text: root.info ? PR.shortId(root.info.commit)
                    + (root.info.updated && root.info.updated !== root.info.installed ? " · updated " + root.when(root.info.updated) : "")
                    + " · installed " + root.when(root.info.installed) : ""
            }

            PluginSourceRow {
                width: body.width
                label: "Before the last update"
                text: root.info && root.info.previous !== "" ? PR.shortId(root.info.previous)
                    : "Nothing yet: it hasn't been updated since it was installed."
                key: root.info && root.info.previous !== "" ? "Go back" : ""
                keyIcon: "undo"
                busy: !!root.job && root.job.kind === "goback" && root.job.state === "running"
                onKeyClicked: PluginRepoService.goBack(root.repo)
            }

            PluginSourceRow {
                width: body.width
                readonly property bool pinned: !!root.info && root.info.pinned
                label: "Pin"
                text: pinned ? "On. Updates skip it, and say so." : "Off. Pinned, updates skip it and say so."
                key: pinned ? "Unpin" : "Pin here"
                keyIcon: "push_pin"
                onKeyClicked: PluginRepoService.pin(root.repo, !pinned)
            }

            PluginSourceRow {
                width: body.width
                label: "Remove"
                text: "The repository and its " + (root.states.length === 1 ? "1 plugin" : root.states.length + " plugins") + ". It asks first."
                key: "Remove…"
                onKeyClicked: root.removeRequested()
            }
        }
    }
}
