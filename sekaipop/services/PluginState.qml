import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import "../modules/common/functions/PluginManifest.js" as PM

// One desktop widget plugin's state (PluginService.qml makes one per plugin found). It has
// the same shape as a built-in widget's service (UserCardService.qml): loaded, shown,
// posX / posY / posScale, screenName, setShown / setPosition / persist, snapshot / restore.
// That is what lets Edit Desktop (EditMode.svcOf), the copies on other monitors
// (WidgetClones.qml) and the desktop presets (PresetWidgets.all) treat a plugin like any
// other widget without knowing it is one.
//
// What is the plugin's own on top of that:
//   settings   the manifest's defaults with the user's values on top (PM.mergeSettings);
//              changed with setSetting(), by the widget (host.setSetting) or by
//              `qs -c sekaipop ipc call plugins set <id> <key> <value>`
//   secrets    read at start from the environment or a file the manifest names (and
//              again by reloadSecrets(), Settings' Reload); never saved here and never
//              part of a preset. secretSources says where each one was found, for
//              Settings, which never shows a value.
//   barShown   its entry is on the bar (a plugin whose manifest has `bar`), the bar's own
//              on / off switch for it, as `bar.<module>` is for a built-in one
//              (BarLayoutService.isOn); saved here, off until the user turns it on
//   service    the plugin's Service.qml, made once and shared by its widget, its bar
//              entries and its popups (`host.service`), so three surfaces on three monitors
//              poll once. It runs while any of them shows: `wanted` lists which.
QtObject {
    id: root

    // The manifest, as PluginManifest.parse() filled it in.
    required property var plugin
    // The plugin's folder (Widget.qml is in it).
    required property string dir

    readonly property string pluginId: root.plugin.id
    // The id everything else knows it by: Edit Desktop, the copies, presets, Focus Mode.
    readonly property string widgetId: "plugin:" + root.plugin.id

    property bool loaded: false
    property bool shown: false
    property bool barShown: false
    property real posX: -1
    property real posY: -1
    property real posScale: 0
    property string screenName: ""
    property var settings: PM.mergeSettings(root.plugin.settings, null)
    property var secrets: ({})
    // { name: "env" | "file" | "" }: where each secret was found; "" = not found.
    property var secretSources: ({})

    // A copy on another monitor decides which monitors get a window from where the main
    // copy is (WidgetClones.rebuild), the same as the built-in widgets' Connections there.
    onScreenNameChanged: WidgetClones.rebuild()

    function setPosition(x, y, screen, scale) {
        if (!root.loaded)
            return
        root.posX = x
        root.posY = y
        if (typeof scale === "number" && scale > 0)
            root.posScale = scale
        if (typeof screen === "string" && screen !== "")
            root.screenName = screen
        root.saveTimer.stop()
        root.saver.save(root.snapshot())
    }

    function setShown(value) {
        root.shown = value
        root.persist()
    }

    function setBarShown(value) {
        root.barShown = value
        root.persist()
    }

    // ===== what is showing, for the service =====
    // Each surface that shows says so under its own key ("widget:DP-1", "bar:DP-1",
    // "popup:DP-1"), so one going away never switches off another. `wanted` is the kinds
    // that are showing, in this order: a service checks slowly for "bar" alone and at its
    // own pace when a "popup" or a "widget" is up.
    property var claims: ({})

    function want(key, on) {
        if (!!root.claims[key] === !!on)
            return
        const c = Object.assign({}, root.claims)
        if (on)
            c[key] = true
        else
            delete c[key]
        root.claims = c
    }

    readonly property var wanted: {
        const out = []
        for (const kind of ["widget", "bar", "popup"]) {
            if (Object.keys(root.claims).some(k => k.indexOf(kind + ":") === 0))
                out.push(kind)
        }
        return out
    }
    readonly property bool working: root.wanted.length > 0

    // false when the plugin does not declare `key` or the value is not of its type.
    function setSetting(key, value) {
        if (!(key in root.plugin.settings))
            return false
        const v = PM.coerce(root.plugin.settings[key], value)
        if (v === undefined)
            return false
        const s = Object.assign({}, root.settings)
        s[key] = v
        root.settings = s
        root.persist()
        return true
    }

    // Settings' reset: one setting, or all of them, back to the manifest's default.
    function resetSetting(key) {
        if (key in root.plugin.settings)
            root.setSetting(key, root.plugin.settings[key])
    }

    function resetAll() {
        root.settings = PM.mergeSettings(root.plugin.settings, null)
        root.persist()
    }

    // ===== persistence =====
    readonly property string script: Directories.script("state/plugin-state.sh")

    function snapshot() {
        return JSON.stringify({
            x: root.posX,
            y: root.posY,
            scale: root.posScale,
            screen: root.screenName,
            shown: root.shown,
            bar: root.barShown,
            settings: root.settings
        })
    }

    function restore(text) {
        const s = PM.readState(text, root.plugin.settings)
        root.posX = s.x
        root.posY = s.y
        root.posScale = s.scale
        root.screenName = s.screen
        root.shown = s.shown
        root.barShown = s.bar
        root.settings = s.settings
        root.loaded = true
    }

    function persist() {
        if (root.loaded)
            root.saveTimer.restart()
    }

    property Timer saveTimer: Timer {
        interval: 300
        onTriggered: root.saver.save(root.snapshot())
    }

    property Process loader: Process {
        running: true
        command: ["sh", root.script, "load", root.pluginId]
        stdout: StdioCollector {
            onStreamFinished: root.restore(text)
        }
    }

    // Fire-and-forget save that never drops the last state (same as UserCardService's).
    property Process saver: Process {
        property var pending: null

        function save(json) {
            if (running) {
                pending = json
                return
            }
            pending = null
            exec(["sh", root.script, "save", root.pluginId, json])
        }

        onExited: {
            if (pending !== null) {
                const json = pending
                pending = null
                exec(["sh", root.script, "save", root.pluginId, json])
            }
        }
    }

    // ===== secrets =====
    // The environment first (it is there at once), then the file. A file secret arrives a
    // moment after start; the widget sees host.secrets change, like any other binding.
    readonly property var secretFiles: {
        const out = []
        const names = Object.keys(root.plugin.secrets)
        for (const n of names) {
            const d = root.plugin.secrets[n]
            const env = d.env !== "" ? (Quickshell.env(d.env) || "") : ""
            if (env === "" && d.file !== "")
                out.push({ name: n, path: PM.expandPath(d.file, Quickshell.env("HOME") || "", root.dir) })
        }
        return out
    }

    Component.onCompleted: {
        root.reloadSecrets()
        root.makeService()
    }

    // The environment is the shell's own, so only a file can change while it runs; this reads
    // the files again (Settings' Reload, after the user has put a token in place).
    function reloadSecrets() {
        const s = {}
        const src = {}
        for (const n in root.plugin.secrets) {
            const d = root.plugin.secrets[n]
            s[n] = d.env !== "" ? (Quickshell.env(d.env) || "") : ""
            src[n] = s[n] !== "" ? "env" : ""
        }
        root.secrets = s
        root.secretSources = src
        if (root.secretReader.running)
            root.secretsAgain = true
        else {
            root.secretIndex = 0
            root.readNextSecret()
        }
    }

    property int secretIndex: 0
    // A reload asked for while the files were still being read: start over when they are done.
    property bool secretsAgain: false

    function readNextSecret() {
        if (root.secretsAgain) {
            root.secretsAgain = false
            root.reloadSecrets()
            return
        }
        if (root.secretIndex >= root.secretFiles.length)
            return
        const f = root.secretFiles[root.secretIndex]
        root.secretReader.name = f.name
        root.secretReader.exec(["sh", root.script, "secret", f.path])
    }

    property Process secretReader: Process {
        property string name: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const v = text.trim()
                const s = Object.assign({}, root.secrets)
                s[root.secretReader.name] = v
                root.secrets = s
                const src = Object.assign({}, root.secretSources)
                src[root.secretReader.name] = v !== "" ? "file" : ""
                root.secretSources = src
                root.secretIndex = root.secretIndex + 1
                root.readNextSecret()
            }
        }
    }

    // ===== the service =====
    // What Service.qml is handed: the part of `host` that is not about a surface (no theme,
    // monitor or size). Its `working` is true while any surface shows; `wanted` says which.
    readonly property QtObject serviceHost: QtObject {
        readonly property int apiVersion: PM.API_VERSION
        readonly property string id: root.pluginId
        readonly property string name: root.plugin.name
        readonly property string version: root.plugin.version
        readonly property string dir: root.dir
        readonly property var settings: root.settings
        readonly property var secrets: root.secrets
        readonly property bool working: root.working
        readonly property var wanted: root.wanted

        function path(rel) {
            return root.dir + "/" + rel
        }

        function reloadSecrets() {
            root.reloadSecrets()
        }

        function setSetting(key, value) {
            return root.setSetting(key, value)
        }
    }

    // null when the plugin has no Service.qml, or it did not load (the error is logged).
    property var service: null

    property Component serviceComponent: null

    function makeService() {
        if (!root.plugin.files || !root.plugin.files.service)
            return
        root.serviceComponent = Qt.createComponent("file://" + root.dir + "/Service.qml", Component.Asynchronous)
        if (root.serviceComponent.status === Component.Loading)
            root.serviceComponent.statusChanged.connect(root.serviceReady)
        else
            root.serviceReady()
    }

    function serviceReady() {
        const c = root.serviceComponent
        if (!c || c.status === Component.Loading)
            return
        if (c.status === Component.Error) {
            console.warn("PluginState: " + root.pluginId + "/Service.qml did not load: " + c.errorString())
            return
        }
        // Made with the state as its parent, so it goes when the plugin does.
        root.service = c.createObject(root, { host: root.serviceHost })
        if (!root.service)
            console.warn("PluginState: " + root.pluginId + "/Service.qml could not be made (does it declare `required property var host`?)")
    }

    Component.onDestruction: {
        if (root.service)
            root.service.destroy()
    }
}
