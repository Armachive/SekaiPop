import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import "../../common/functions/PluginRepos.js" as PR

// One repository in Get plugins (SettingsGetPlugins.qml): from the reviewed list (its tags,
// what it does, the programs it needs, checked) or read from a URL (`fromUrl`: the plugins in
// it, not reviewed). Its key installs it; then the same row shows the clone's progress, and
// what's next once it is in, or what went wrong.
Item {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    // PR.parseList()'s entry: { repo, description, tags, needs, sekaipop }
    property var entry: ({ repo: "", description: "", tags: [], needs: [], sekaipop: "" })
    // The tags the search matched (marked).
    property var hits: []
    property string shellVersion: ""
    property bool installed: false
    // Installing waits (offline).
    property bool waiting: false
    // Read from a URL: the plugins in it ([plugin]) and the folders that failed their check.
    property bool fromUrl: false
    property var looked: []
    property var lookedBad: []

    signal placeRequested()
    signal settingsRequested(string id)

    readonly property var job: PluginRepoService.jobs[root.entry.repo] ?? null
    readonly property bool installing: !!root.job && root.job.kind === "install" && root.job.state === "running"
    readonly property bool done: !!root.job && root.job.kind === "install" && root.job.state === "done"
    readonly property bool partial: !!root.job && root.job.kind === "install" && root.job.state === "partial"
    readonly property bool failed: !!root.job && root.job.kind === "install" && root.job.state === "failed"
    readonly property bool tooNew: !root.fromUrl && root.entry.sekaipop !== "" && root.shellVersion !== ""
        && !PR.versionAtLeast(root.shellVersion, root.entry.sekaipop)
    readonly property var needs: PR.needsChecked(root.entry.needs, PluginRepoService.needsFound)

    // The plugins this install brought in, as states (once the scan has found them).
    readonly property var newStates: root.job && root.job.plugins
        ? root.job.plugins.map(p => PluginService.stateFor(p.id)).filter(s => !!s) : []
    readonly property var barStates: root.newStates.filter(s => !!s.plugin.bar)
    readonly property bool anyWidget: root.newStates.some(s => s.plugin.files.widget)
    readonly property bool barsOn: root.barStates.length > 0 && root.barStates.every(s => s.barShown)

    implicitHeight: main.implicitHeight + 28

    Rectangle {
        anchors.fill: parent
        radius: 20
        color: mt.pSurfaceHover
        opacity: area.containsMouse ? 1 : 0
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
        x: 18
        y: 14
        icon: root.fromUrl ? "link" : (root.entry.tags.indexOf("bar") >= 0 ? "toolbar" : "widgets")
        opacity: root.tooNew ? 0.55 : 1
    }

    Column {
        id: main
        x: 18 + 46 + 18
        y: 14
        width: root.width - x - ends.width - 14 - 18
        spacing: 6

        // the repository and its tags
        Flow {
            width: parent.width
            spacing: 8

            Text {
                height: 26
                verticalAlignment: Text.AlignVCenter
                text: root.entry.repo
                color: mt.pInk
                font.family: mt.fontFamily
                font.pixelSize: 18
                font.weight: Font.ExtraBold
            }

            PluginBadge {
                visible: root.fromUrl
                y: 1
                kind: "mute"
                text: "not reviewed"
            }

            Repeater {
                model: root.entry.tags

                delegate: Rectangle {
                    required property string modelData
                    readonly property bool hit: root.hits.indexOf(modelData) >= 0
                    y: 1
                    width: tagText.implicitWidth + 18
                    height: 24
                    radius: 8
                    color: hit ? mt.attributeColors[0] : "transparent"
                    border.width: 2
                    border.color: hit ? mt.colBorder : mt.pLine

                    Text {
                        id: tagText
                        anchors.centerIn: parent
                        text: modelData
                        color: parent.hit ? mt.colBorder : mt.pInkSub
                        font.family: mt.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.ExtraBold
                    }
                }
            }
        }

        // what it does (the list's words; from a URL, the plugins in it)
        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            textFormat: Text.StyledText
            text: {
                if (!root.fromUrl)
                    return root.entry.description
                const n = root.looked.length
                if (n === 0)
                    return ""
                const parts = root.looked.map(p => "<b>" + p.name + "</b> " + p.version + " (" + PR.kindText(p) + ")")
                return (n === 1 ? "1 plugin in it: " : n + " plugins in it: ") + PR.namesText(parts)
                    + ", made for this SekaiPop's plugin api."
                    + (root.lookedBad.length > 0 ? " " + root.lookedBad.length + " more didn't pass its check and would be under Didn't load." : "")
            }
            color: mt.pInkSub
            font.family: mt.fontFamily
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

        // what it needs, checked against PATH
        Flow {
            visible: !root.done && !root.partial && (root.needs.list.length > 0 || root.fromUrl)
            width: parent.width
            spacing: 6

            Text {
                visible: !root.fromUrl
                height: 24
                verticalAlignment: Text.AlignVCenter
                text: "Needs"
                color: mt.pInkSub
                font.family: mt.fontFamily
                font.pixelSize: 13
                font.weight: Font.Bold
            }

            Repeater {
                model: root.needs.list

                delegate: Rectangle {
                    required property var modelData
                    width: needRow.implicitWidth + 16
                    height: 24
                    radius: 8
                    color: modelData.ok ? mt.pSurfaceHover : mt.attributeColors[2]

                    Row {
                        id: needRow
                        anchors.centerIn: parent
                        spacing: 4

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            size: 12
                            name: modelData.ok ? "check" : "close"
                            color: modelData.ok ? mt.pInk : mt.colBorder
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.name
                            color: modelData.ok ? mt.pInk : mt.colBorder
                            font.family: "monospace"
                            font.pixelSize: 12
                        }
                    }
                }
            }

            Text {
                height: 24
                verticalAlignment: Text.AlignVCenter
                text: root.fromUrl ? "A repository off the list says nothing about what it needs; check its README."
                    : root.needs.missing.length > 0
                        ? "· " + PR.namesText(root.needs.missing) + (root.needs.missing.length === 1 ? " isn't" : " aren't") + " installed: it installs, but won't work fully until " + (root.needs.missing.length === 1 ? "it is" : "they are") + "."
                        : ""
                color: mt.pInkSub
                font.family: mt.fontFamily
                font.pixelSize: 13
                font.weight: Font.Bold
            }
        }

        // a newer SekaiPop needed
        Flow {
            visible: root.tooNew
            width: parent.width
            spacing: 8

            PluginBadge {
                kind: "warn"
                text: "Needs SekaiPop " + root.entry.sekaipop
            }

            Text {
                height: 30
                verticalAlignment: Text.AlignVCenter
                text: "This is " + root.shellVersion + ". Update SekaiPop in About › Update, then it installs."
                color: mt.pInkSub
                font.family: mt.fontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
        }

        // installing: the clone's progress
        Row {
            visible: root.installing
            spacing: 12

            PluginMeter {
                anchors.verticalCenter: parent.verticalCenter
                value: root.job ? root.job.pct / 100 : 0
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.StyledText
                text: root.job ? "<b>" + root.job.step + (root.job.step === "Cloning" ? " " + root.job.pct + "%" : "…") + "</b> · then check, link, reload" : ""
                color: mt.pInkSub
                font.family: mt.fontFamily
                font.pixelSize: 13
                font.weight: Font.Bold
            }
        }

        // in: what's next
        PluginNote {
            visible: root.done || root.partial
            width: parent.width
            icon: root.partial ? "rule" : "check_circle"
            text: {
                if (!root.job || !root.job.names)
                    return ""
                const names = PR.namesText(root.job.names)
                if (root.partial)
                    return "<b>" + names + (root.job.names.length === 1 ? " is" : " are") + " in.</b> "
                        + PR.namesText(root.job.bad.map(b => b.id)) + " didn't pass " + (root.job.bad.length === 1 ? "its" : "their") + " check, so "
                        + (root.job.bad.length === 1 ? "it's" : "they're") + " under Didn't load: " + (root.job.bad[0] ? root.job.bad[0].error : "") + ". To fix: the plugin's author."
                const one = root.job.plugins.length === 1 ? root.job.plugins[0] : null
                return "<b>" + names + (root.job.names.length === 1 ? " is" : " are") + " installed.</b> "
                    + (one ? "It has " + PR.kindText(one) + ", " + (one.bar && one.files.widget ? "both" : "") + " off until you put "
                        + (one.bar && one.files.widget ? "them" : "it") + " somewhere."
                        : "Their bar entries and widgets are off until you put them somewhere.")
            }

            SettingChip {
                visible: root.barStates.length > 0
                capH: 36
                fontSize: 14
                selected: root.barsOn
                label: root.barsOn ? (root.barStates.length === 1 ? "Its bar entry is on" : "Their bar entries are on")
                    : (root.barStates.length === 1 ? "Turn its bar entry on" : "Turn their bar entries on")
                onClicked: {
                    const on = !root.barsOn
                    for (const st of root.barStates)
                        st.setBarShown(on)
                }
            }

            SettingChip {
                visible: root.anyWidget
                capH: 36
                fontSize: 14
                label: root.newStates.filter(s => s.plugin.files.widget).length === 1 ? "Place its widget in Edit Desktop" : "Place the widgets in Edit Desktop"
                onClicked: root.placeRequested()
            }

            SettingChip {
                visible: root.newStates.length > 0
                capH: 36
                fontSize: 14
                label: "Its settings"
                onClicked: root.settingsRequested(root.newStates[0].pluginId)
            }
        }

        // didn't go in
        Flow {
            visible: root.failed
            width: parent.width
            spacing: 8

            PluginBadge {
                kind: "tag"
                text: "NOT INSTALLED"
            }

            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: root.job && root.job.message ? root.job.message : ""
                color: mt.pInk
                font.family: mt.fontFamily
                font.pixelSize: 15
                font.weight: Font.Bold
            }
        }
    }

    Row {
        id: ends
        x: root.width - width - 14
        y: 14
        spacing: 12

        SettingChip {
            visible: !root.installed && !root.installing && !root.done && !root.partial && !root.tooNew
            capH: 36
            fontSize: 14
            selected: !root.waiting
            enabled: !root.waiting
            opacity: root.waiting ? 0.45 : 1
            label: root.failed ? "Try again" : root.fromUrl ? "Install it anyway" : "Install"
            icon: "download"
            onClicked: {
                PluginRepoService.clearJob(root.entry.repo)
                PluginRepoService.install(root.entry.repo, !root.fromUrl)
            }
        }

        PluginBadge {
            visible: (root.installed && !root.installing) || root.done || root.partial
            anchors.verticalCenter: parent.verticalCenter
            kind: root.partial ? "warn" : "on"
            icon: root.partial ? "" : "check"
            text: root.partial ? (root.job ? root.job.badge : "") : "Installed"
        }

        SettingRoundButton {
            visible: PR.REPO_RE.test(root.entry.repo)
            size: 44
            icon: "open_in_new"
            onClicked: Qt.openUrlExternally("https://github.com/" + root.entry.repo)
        }
    }
}
