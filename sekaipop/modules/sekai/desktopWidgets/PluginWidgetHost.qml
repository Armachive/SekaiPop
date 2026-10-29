import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sekai.editMode

// The window a desktop widget PLUGIN is drawn in (services/PluginService.qml,
// docs/PLUGINS.md). Everything about where a widget is belongs to the shell and lives
// here, once, for every plugin: the spot and the monitor, dragging (on an unlocked desktop
// and in Edit Desktop), copies on other monitors, the pop in and the swallow out, Desktop
// Focus Mode, the shell scale and the shelf's picture. The plugin's Widget.qml only draws.
//
// It is the user card's window (UserCardWidget.qml, which says how each part works) with
// the card's content swapped for a Loader of the plugin's Widget.qml. What is left out:
// the preset "shrink away" motion (PresetMotion.qml has a flag per built-in widget; a
// plugin just uses its show / hide animation, as PresetWidgets.qml allows).
//
// The widget is handed one object, `host` (below). It is the only part of the shell a
// plugin can reach: a file outside the shell's folder cannot import `qs.*`.
//
// Its size is the widget's implicitWidth x implicitHeight in design pixels (the shell
// scale is applied around it), plus the frame when the manifest keeps it.

PanelWindow {
    id: win

    // The plugin's id (its folder name), not "plugin:<id>".
    required property string pluginId

    // Which monitor it lives on, by name. Empty = the one it was last dropped on.
    property string monitor: ""
    // A copy on another monitor (WidgetClones.qml), with a spot of its own.
    property bool clone: false

    readonly property var st: PluginService.stateFor(win.pluginId)
    readonly property var plugin: win.st ? win.st.plugin : null
    readonly property string widgetId: "plugin:" + win.pluginId

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(screen)

    function resetPosition(): void {
        win.clearSpot();
        win.place();
        win.saveSpot(card.x, card.y);
    }

    readonly property var cloneSpot: win.clone ? WidgetClones.spot(win.widgetId, win.wantedScreen) : null
    readonly property bool stLoaded: !!win.st && win.st.loaded
    readonly property bool spotReady: win.clone ? (WidgetClones.loaded && win.cloneSpot !== null) : win.stLoaded
    readonly property real spotX: win.clone ? (win.cloneSpot ? win.cloneSpot.x : -1) : (win.st ? win.st.posX : -1)
    readonly property real spotY: win.clone ? (win.cloneSpot ? win.cloneSpot.y : -1) : (win.st ? win.st.posY : -1)
    readonly property real spotScale: win.clone ? (win.cloneSpot ? win.cloneSpot.scale : 0) : (win.st ? win.st.posScale : 0)

    function saveSpot(x, y): void {
        if (win.clone)
            WidgetClones.setSpot(win.widgetId, win.wantedScreen, x, y, win.uiScale)
        else if (win.st)
            win.st.setPosition(x, y, win.screen ? win.screen.name : "", win.uiScale)
    }

    function clearSpot(): void {
        if (win.clone) {
            WidgetClones.clearSpot(win.widgetId, win.wantedScreen)
        } else if (win.st) {
            win.st.posX = -1
            win.st.posY = -1
        }
    }

    function fixSpotScale(): void {
        if (win.clone) {
            WidgetClones.setSpot(win.widgetId, win.wantedScreen, win.spotX, win.spotY, win.uiScale)
        } else if (win.st) {
            win.st.posScale = win.uiScale
            win.st.persist()
        }
    }

    readonly property string wantedScreen: win.monitor !== "" ? win.monitor : (win.st ? win.st.screenName : "")
    screen: Quickshell.screens.find(s => s.name === win.wantedScreen) ?? DesktopMonitors.fallbackScreen

    readonly property real uiScale: ShellScale.forScreen(win.screen)
    readonly property real fullW: win.screen ? win.screen.width : 0
    readonly property real fullH: win.screen ? win.screen.height : 0
    readonly property real roomW: win.fullW / win.uiScale
    readonly property real roomH: win.fullH / win.uiScale

    // ===== a small window while nothing needs the whole screen (see UserCardWidget.qml) =====
    readonly property bool compact: !EditMode.active && !win.gliding && EditMode.screenName === ""
        && EditMode.compactWindows && !EditMode.desktopDragAllowed && win.fullW > 0 && win.placed
    readonly property real boxPad: Math.ceil((0.16 * Math.max(card.width, card.height) + 24) * win.uiScale)
    readonly property real boxX: win.compact ? Math.max(0, Math.floor(card.x * win.uiScale - win.boxPad)) : 0
    readonly property real boxY: win.compact ? Math.max(0, Math.floor(card.y * win.uiScale - win.boxPad)) : 0
    readonly property real boxW: Math.max(1, Math.min(win.fullW,
        Math.ceil((card.x + card.width) * win.uiScale + win.boxPad)) - win.boxX)
    readonly property real boxH: Math.max(1, Math.min(win.fullH,
        Math.ceil((card.y + card.height) * win.uiScale + win.boxPad)) - win.boxY)

    // ===== on / off, and Desktop Focus Mode =====
    FocusGate {
        id: gate
        widgetId: win.widgetId
        screenName: win.screen ? win.screen.name : ""
    }

    readonly property bool switchedOn: win.stLoaded && win.st.shown
    readonly property bool want: win.switchedOn && gate.show
    property real reveal: 0
    property bool armed: false
    property bool placed: false

    onWantChanged: {
        if (!win.armed) {
            popIn.stop()
            swallow.stop()
            win.reveal = win.want ? 1 : 0
        } else if (win.want) {
            swallow.stop()
            popIn.restart()
        } else {
            popIn.stop()
            swallow.restart()
        }
    }

    NumberAnimation {
        id: popIn
        target: win
        property: "reveal"
        to: 1
        duration: 460
        easing.type: Easing.OutBack
        easing.overshoot: 1.9
    }

    NumberAnimation {
        id: swallow
        target: win
        property: "reveal"
        to: 0
        duration: 300
        easing.type: Easing.InCubic
    }

    Timer {
        interval: 800
        running: win.stLoaded
        onTriggered: win.armed = true
    }

    readonly property bool live: win.want || win.reveal > 0.001

    // What the widget is told as `host.working`: on screen, or switched on and not suspended
    // by Focus Mode. A widget that polls something should poll only while this is true.
    readonly property bool working: win.live || (win.switchedOn && !gate.suspended)

    // Tells the plugin's shared service that a widget is up (PluginState.want), under a key
    // of this window's own, so a copy on another monitor going away does not switch it off.
    property string claimed: ""

    function syncClaim(): void {
        const key = win.st && win.working ? "widget:" + (win.clone ? "copy:" : "") + win.wantedScreen : ""
        if (key === win.claimed)
            return
        if (win.claimed !== "" && win.st)
            win.st.want(win.claimed, false)
        win.claimed = key
        if (key !== "")
            win.st.want(key, true)
    }

    onWorkingChanged: win.syncClaim()
    onWantedScreenChanged: win.syncClaim()
    onStChanged: win.syncClaim()
    Component.onDestruction: {
        if (win.claimed !== "" && win.st)
            win.st.want(win.claimed, false)
    }

    visible: win.stLoaded && (win.live || EditMode.active)

    WlrLayershell.layer: (chrome.raised || WallpaperService.restacking) ? WlrLayer.Bottom : WlrLayer.Background
    WlrLayershell.namespace: "sekaipop-plugin-" + win.pluginId
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        top: true
        left: true
        right: !win.compact
        bottom: !win.compact
    }

    margins {
        left: win.boxX
        top: win.boxY
    }

    implicitWidth: win.boxW
    implicitHeight: win.boxH

    mask: Region {
        item: cardMask
    }

    Item {
        id: cardMask
        readonly property real m: stage.editing ? 38 : 0
        readonly property real k: win.uiScale * stage.scale
        readonly property real x1: shifter.x + stage.x + (card.x + card.width + m) * k
        readonly property real y1: shifter.y + stage.y + (card.y + card.height + m) * k
        x: !win.live ? 0 : Math.max(0, Math.round(shifter.x + stage.x + (card.x - m) * k))
        y: !win.live ? 0 : Math.max(0, Math.round(shifter.y + stage.y + (card.y - m) * k))
        width: !win.live ? 1 : Math.max(0, Math.ceil(x1) - x)
        height: !win.live ? 1 : Math.max(0, Math.ceil(y1) - y)
    }

    // ===== what the plugin is handed =====
    // This object is the plugin interface (docs/PLUGINS.md, "The host object"). Add to it
    // freely; renaming or removing anything is a new PluginManifest.API_VERSION.
    QtObject {
        id: hostApi

        readonly property int apiVersion: PluginService.apiVersion
        readonly property string id: win.pluginId
        readonly property string name: win.plugin ? win.plugin.name : ""
        readonly property string version: win.plugin ? win.plugin.version : ""
        // The plugin's folder, for its own files: Image { source: "file://" + host.path("icon.png") }
        readonly property string dir: win.st ? win.st.dir : ""

        // The theme of the monitor it is on (docs/PLUGINS.md lists the names that are promised).
        readonly property var theme: win.mt

        readonly property var settings: win.st ? win.st.settings : ({})
        readonly property var secrets: win.st ? win.st.secrets : ({})

        readonly property string screenName: win.screen ? win.screen.name : ""
        readonly property real scale: win.uiScale
        readonly property bool clone: win.clone
        // On screen (or about to be): run timers and fetches only while this is true.
        readonly property bool working: win.working
        // The plugin's Service.qml, shared with its bar entries and popups; null without one.
        readonly property var service: win.st ? win.st.service : null
        // Which of the plugin's surfaces are showing ("widget", "bar", "popup").
        readonly property var wanted: win.st ? win.st.wanted : []
        // Edit Desktop is on for this monitor, and whether this widget is the one selected
        // there (then it should work as it does on the desktop).
        readonly property bool editing: chrome.editing
        readonly property bool selected: chrome.selected

        function path(rel) {
            return hostApi.dir + "/" + rel
        }

        // Read the secret files again (what Settings' Reload does), for a widget's own
        // "check again" after the user put a token in place. `secrets` changes when they
        // arrive. An environment variable is still the one the shell started with.
        function reloadSecrets() {
            if (win.st)
                win.st.reloadSecrets()
        }

        function setSetting(key, value) {
            return win.st ? win.st.setSetting(key, value) : false
        }
    }

    // ===== placement (see UserCardWidget.qml) =====
    function place(force) {
        if (win.roomW <= 0 || win.roomH <= 0)
            return
        if (!force && (!win.stLoaded || win.roomW < card.width || win.roomH < card.height))
            return
        let x = win.spotX
        let y = win.spotY
        if (x < 0 || y < 0) {
            // A first spot: the middle of the screen, a little above centre.
            x = (win.roomW - card.width) / 2
            y = (win.roomH - card.height) / 3
        } else if (win.spotScale > 0 && win.uiScale > 0) {
            const k = win.spotScale / win.uiScale
            x *= k
            y *= k
        }
        card.x = Math.max(0, Math.min(x, win.roomW - card.width))
        card.y = Math.max(0, Math.min(y, win.roomH - card.height))
        win.placed = true
    }

    Timer {
        id: settle
        interval: 300
        onTriggered: {
            if (win.spotReady && win.spotX >= 0 && win.spotScale <= 0 && !dragArea.drag.active)
                win.fixSpotScale()
            if (!chrome.dragging && !dragArea.drag.active)
                win.place(!win.placed && win.stLoaded)
        }
    }

    onWidthChanged: { win.place(); settle.restart() }
    onHeightChanged: { win.place(); settle.restart() }
    onUiScaleChanged: { win.place(); settle.restart() }
    onScreenChanged: { win.place(); settle.restart() }
    onVisibleChanged: settle.restart()
    onStLoadedChanged: { win.place(); settle.restart() }
    Component.onCompleted: {
        win.reveal = win.want ? 1 : 0
        win.place()
        win.syncClaim()
    }

    Connections {
        target: WidgetClones
        enabled: win.clone
        function onSpotsChanged() { follow.restart() }
    }

    // A preset or `ipc plugins resetPosition` hands the state another spot.
    Connections {
        target: win.st
        enabled: !win.clone
        function onPosXChanged() { follow.restart() }
        function onPosYChanged() { follow.restart() }
        function onPosScaleChanged() { follow.restart() }
    }

    property bool gliding: false
    property bool glideOn: false

    Timer {
        id: follow
        interval: 16
        onTriggered: {
            if (chrome.dragging || dragArea.drag.active)
                return
            const ox = card.x
            const oy = card.y
            win.place()
            if (Math.abs(card.x - ox) + Math.abs(card.y - oy) < 2)
                return
            card.x = ox
            card.y = oy
            win.gliding = true
            glideStart.restart()
        }
    }

    Timer {
        id: glideStart
        interval: 80
        onTriggered: {
            win.glideOn = true
            win.place()
            glideEnd.restart()
        }
    }

    Timer {
        id: glideEnd
        interval: 640
        onTriggered: {
            win.glideOn = false
            win.gliding = false
        }
    }

    EditPreview {
        widgetId: win.clone ? "" : win.widgetId
        target: card
        pixelRatio: win.uiScale
    }

    // ===== Edit Desktop =====
    Item {
        id: shifter
        x: -win.boxX
        y: -win.boxY
        width: win.fullW
        height: win.fullH

        EditStage {
            id: stage
            screenObj: win.screen
            uiScale: win.uiScale

            ScaleHost {
                anchors.fill: parent
                factor: win.uiScale

                Item {
                    id: card

                    Behavior on x {
                        enabled: win.glideOn
                        NumberAnimation { duration: 520; easing.type: Easing.OutBack; easing.overshoot: 0.9 }
                    }
                    Behavior on y {
                        enabled: win.glideOn
                        NumberAnimation { duration: 520; easing.type: Easing.OutBack; easing.overshoot: 0.9 }
                    }

                    readonly property bool classicPanel: true
                    readonly property bool framed: !win.plugin || win.plugin.frame
                    readonly property int inset: card.framed ? win.mt.borderWidth + win.mt.outerRingWidth + 10 : 0

                    // The widget's own size, kept sane: a widget that reports nothing yet (it is
                    // still loading) or something absurd can't make a window of 0 or of a mile.
                    readonly property real contentW: Math.max(24, Math.min(1600, slot.item ? slot.item.implicitWidth : 160))
                    readonly property real contentH: Math.max(24, Math.min(1200, slot.item ? slot.item.implicitHeight : 80))

                    width: card.contentW + card.inset * 2
                    height: card.contentH + card.inset * 2 + (card.framed ? win.mt.shadowOffset : 0)

                    scale: Math.max(0, win.reveal) * (win.placed ? 1 : 0)
                    transformOrigin: Item.Center

                    onWidthChanged: {
                        if (!chrome.dragging && !dragArea.drag.active)
                            win.place()
                    }

                    onHeightChanged: {
                        if (!chrome.dragging && !dragArea.drag.active)
                            win.place()
                    }

                    // The same housing as the built-in cards.
                    Pill {
                        visible: card.framed
                        anchors.fill: parent
                        cornerRadius: win.mt.radiusOuter
                        ringWidth: win.mt.borderWidth + win.mt.outerRingWidth
                        ringColorTop: win.mt.pSurfaceRing
                        ringColorBottom: ringColorTop
                        fillColor: win.mt.pSurface
                    }

                    EditChrome {
                        id: chrome
                        widgetId: win.widgetId
                        target: card
                        roomW: win.roomW
                        roomH: win.roomH
                        screenName: win.screen ? win.screen.name : ""
                        onMoved: win.saveSpot(card.x, card.y)
                        onRemoveRequested: EditMode.removeFrom(win.widgetId, win.screen ? win.screen.name : "")
                    }

                    // Dragging on an unlocked desktop (and while selected in Edit Desktop). It is
                    // UNDER the widget, so whatever the widget makes clickable keeps its clicks,
                    // and the rest of the card is a handle.
                    MouseArea {
                        id: dragArea
                        z: 1
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        cursorShape: EditMode.desktopDragAllowed || chrome.selected
                            ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.ArrowCursor

                        drag.target: EditMode.desktopDragAllowed || chrome.selected ? card : null
                        drag.axis: Drag.XAndYAxis
                        drag.minimumX: 0
                        drag.maximumX: Math.max(0, win.roomW - card.width)
                        drag.minimumY: 0
                        drag.maximumY: Math.max(0, win.roomH - card.height)

                        drag.onActiveChanged: {
                            chrome.ownDrag = drag.active
                            if (!drag.active)
                                win.saveSpot(card.x, card.y)
                        }
                    }

                    // ===== the plugin =====
                    Loader {
                        id: slot
                        z: 2
                        x: card.inset
                        y: card.inset
                        width: card.contentW
                        height: card.contentH
                        asynchronous: false

                        readonly property string url: win.st ? "file://" + win.st.dir + "/Widget.qml" : ""

                        // setSource, so `host` is there before the widget's own bindings run. Once at
                        // start and again only if the folder changes: the first `url` arrives as a
                        // change too, and loading twice would build the widget twice.
                        property bool started: false
                        onUrlChanged: {
                            if (slot.started)
                                slot.load()
                        }
                        Component.onCompleted: {
                            slot.started = true
                            slot.load()
                        }

                        function load() {
                            if (slot.url === "")
                                slot.source = ""
                            else
                                slot.setSource(slot.url, { host: hostApi })
                        }

                        onStatusChanged: {
                            if (slot.status === Loader.Error)
                                console.warn("PluginWidgetHost: " + win.pluginId + "/Widget.qml did not load (see the errors above)")
                        }
                    }

                    // A widget that did not load says so on the card instead of being an empty box.
                    Text {
                        z: 2
                        visible: slot.status === Loader.Error
                        anchors.centerIn: slot
                        width: slot.width - 12
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        text: (win.plugin ? win.plugin.name : win.pluginId) + "\ndid not load"
                        color: win.mt.pInkSub
                        font.family: win.mt.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Bold
                    }
                }
            }
        }
    }
}
