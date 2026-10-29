import QtQuick
import qs.modules.common

// A plugin's popup (docs/PLUGINS.md, "A bar entry"): the face of a SekaiPopup card under
// the plugin's bar entry. The shell does everything around it, as for the built-in popups:
// placing it under the entry on any bar edge, the pop in and the shrink back into the pill,
// closing it on a click away or Escape, and keeping one popup open at a time (Bar.qml). The
// plugin's Popup.qml draws only the card's face.
//
// Its size is Popup.qml's implicitWidth x implicitHeight (design pixels), kept between 280
// and 480 wide and at most 70 % of the screen tall; a card with more to show scrolls inside.
// Popup.qml is built the first time the popup opens, then kept.
SekaiPopup {
    id: root

    // "plugin:<id>", and the plugin's state (services/PluginState.qml).
    required property string key
    required property var st

    readonly property var plugin: root.st ? root.st.plugin : null

    readonly property real maxHeight: {
        const w = root.parentWindow
        const h = w && w.screen ? w.screen.height / root.uiScale : 900
        return Math.max(120, Math.floor(h * 0.7))
    }

    contentWidth: Math.max(280, Math.min(480, slot.item ? slot.item.implicitWidth : 320))
    contentHeight: Math.max(48, Math.min(root.maxHeight, slot.item ? slot.item.implicitHeight : 120))

    // Built once it is first wanted.
    property bool seen: false
    onOpenChanged: {
        if (root.open)
            root.seen = true
        root.syncClaim()
    }

    readonly property string screenName: root.parentWindow && root.parentWindow.screen ? root.parentWindow.screen.name : ""
    property string claimed: ""

    // The service is told a popup is up while it is open.
    function syncClaim() {
        const key = root.st && root.open ? "popup:" + root.screenName : ""
        if (key === root.claimed)
            return
        if (root.claimed !== "" && root.st)
            root.st.want(root.claimed, false)
        root.claimed = key
        if (key !== "")
            root.st.want(key, true)
    }

    Component.onDestruction: {
        if (root.claimed !== "" && root.st)
            root.st.want(root.claimed, false)
    }

    // Keys other than Escape go to Popup.qml, when it has a `keyed(event)` function.
    onKeyed: event => {
        if (slot.item && typeof slot.item.keyed === "function")
            slot.item.keyed(event)
    }

    // ===== what Popup.qml is handed =====
    // The plugin interface (docs/PLUGINS.md, "The host object"); keep it in step with the
    // widget's (PluginWidgetHost.qml) and the bar entry's (PluginBarItem.qml).
    QtObject {
        id: hostApi

        readonly property int apiVersion: root.st ? root.st.serviceHost.apiVersion : 0
        readonly property string id: root.plugin ? root.plugin.id : ""
        readonly property string name: root.plugin ? root.plugin.name : ""
        readonly property string version: root.plugin ? root.plugin.version : ""
        readonly property string dir: root.st ? root.st.dir : ""
        readonly property var theme: root.mt
        readonly property var settings: root.st ? root.st.settings : ({})
        readonly property var secrets: root.st ? root.st.secrets : ({})
        readonly property string screenName: root.screenName
        readonly property real scale: root.uiScale
        readonly property bool working: root.open
        readonly property var service: root.st ? root.st.service : null
        readonly property var wanted: root.st ? root.st.wanted : []

        // What only a popup gets.
        readonly property QtObject popup: QtObject {
            readonly property bool open: root.open
            // The most it may be tall (design pixels): past this the shell clips it, so a
            // long list scrolls inside instead.
            readonly property real maxHeight: root.maxHeight

            // Put the popup away, for an action that ends it (opening a page, signing in).
            function close() {
                root.closeRequested()
            }
        }

        function path(rel) {
            return hostApi.dir + "/" + rel
        }

        function reloadSecrets() {
            if (root.st)
                root.st.reloadSecrets()
        }

        function setSetting(key, value) {
            return root.st ? root.st.setSetting(key, value) : false
        }
    }

    Item {
        width: root.contentWidth
        height: root.contentHeight
        clip: true

        Loader {
            id: slot
            active: root.seen
            width: root.contentWidth
            height: slot.item ? Math.min(slot.item.implicitHeight, root.contentHeight) : 0

            readonly property string url: root.st ? "file://" + root.st.dir + "/Popup.qml" : ""

            onActiveChanged: {
                if (slot.active && slot.url !== "")
                    slot.setSource(slot.url, { host: hostApi })
            }

            onStatusChanged: {
                if (slot.status === Loader.Error)
                    console.warn("PluginPopup: " + root.key + "/Popup.qml did not load (see the errors above)")
            }
        }

        Text {
            visible: slot.status === Loader.Error
            anchors.centerIn: parent
            text: (root.plugin ? root.plugin.name : root.key) + "'s popup did not load"
            color: root.mt.inkSub
            font.family: root.mt.fontFamily
            font.pixelSize: 12
            font.weight: Font.Bold
        }
    }
}
