import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets

// A plugin's entry in the bar (docs/PLUGINS.md, "A bar entry"). The shell draws the pill
// (the same housing as the status and weather pills: outline, ring, chip fill, hard shadow;
// a flat chip in the Capsule style), presses it while its popup is open, and gives it the
// left click; the plugin's Bar.qml draws only what is inside. So an entry fits every bar
// style and edge without knowing them.
//
// Status_Bar.qml makes one per plugin module on the bar and hands it the plugin's state
// (services/PluginState.qml) as plain data, so the bar itself stays free of services.
//
// Bar.qml's root may declare:
//   property bool present   false takes the entry off the bar (no pill, no room), for an
//                           entry with nothing to say right now (default true)
//   property string tip     the hover tag's text (none when empty)
// Its own MouseArea may take the middle and right buttons; the left one is the shell's.
Item {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    // "plugin:<id>", and the plugin's state (PluginState.qml).
    required property string key
    required property var st

    // Fed by Status_Bar.qml.
    property bool vertical: false
    property string barPosition: "top"
    // The module is switched on for this bar (Status_Bar.shows), whether or not the plugin
    // has something to show right now.
    property bool enabledHere: true
    // Its popup is open (Bar.qml's pluginPopup is this key).
    property bool popupOpen: false

    signal clicked()

    readonly property var plugin: root.st ? root.st.plugin : null
    readonly property bool hasPopup: !!root.plugin && root.plugin.files.popup
    readonly property string screenName: QsWindow.window && QsWindow.window.screen ? QsWindow.window.screen.name : ""
    readonly property real uiScale: QsWindow.window && QsWindow.window.uiScale ? QsWindow.window.uiScale : 1

    readonly property bool present: !slot.item || slot.item.present !== false
    readonly property bool loadFailed: slot.status === Loader.Error

    visible: root.enabledHere && (root.present || root.loadFailed)
    implicitWidth: pill.implicitWidth
    implicitHeight: pill.implicitHeight

    // The service runs while an entry is on a bar; the key is this bar's, so the entry on
    // another monitor going away does not switch it off.
    readonly property string claimKey: root.st && root.enabledHere ? "bar:" + root.screenName : ""
    property string claimed: ""

    function syncClaim() {
        if (root.claimKey === root.claimed)
            return
        if (root.claimed !== "" && root.st)
            root.st.want(root.claimed, false)
        root.claimed = root.claimKey
        if (root.claimed !== "")
            root.st.want(root.claimed, true)
    }

    onClaimKeyChanged: root.syncClaim()
    Component.onCompleted: root.syncClaim()
    Component.onDestruction: {
        if (root.claimed !== "" && root.st)
            root.st.want(root.claimed, false)
    }

    // ===== what Bar.qml is handed =====
    // The plugin interface (docs/PLUGINS.md, "The host object"); keep it in step with the
    // widget's (PluginWidgetHost.qml) and the popup's (PluginPopup.qml).
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
        readonly property bool working: root.enabledHere
        readonly property var service: root.st ? root.st.service : null
        readonly property var wanted: root.st ? root.st.wanted : []

        // What only an entry in the bar gets.
        readonly property QtObject bar: QtObject {
            readonly property bool vertical: root.vertical
            // "top", "bottom", "left" or "right".
            readonly property string edge: root.barPosition
            readonly property bool capsule: pill.capsule
            // The ink for the pill it sits in (the chip's), and a quieter one.
            readonly property color ink: root.mt.chipInk
            readonly property color inkSub: Qt.rgba(root.mt.chipInk.r, root.mt.chipInk.g, root.mt.chipInk.b, 0.667)
            readonly property bool popupOpen: root.popupOpen
            readonly property bool hasPopup: root.hasPopup
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

    Pill {
        id: pill
        anchors.fill: parent
        cornerRadius: mt.radiusBadge
        fillColor: mt.chipFill
        // Held down while its popup is open, like a key that stays pressed.
        pressed: area.pressed || root.popupOpen
        ringWidth: 6   // the bar's pills all share the Utility pill's ring

        readonly property real contentW: slot.item ? slot.item.implicitWidth : failText.implicitWidth
        readonly property real contentH: slot.item ? slot.item.implicitHeight : failText.implicitHeight

        implicitWidth: root.vertical ? pill.barVWidth : pill.contentW + (pill.capsule ? 20 : 28)
        implicitHeight: root.vertical
            ? pill.contentH + (pill.capsule ? 4 : 2 * ringWidth) + 8 + mt.shadowOffset
            : mt.pillHeight + mt.shadowOffset

        Loader {
            id: slot
            anchors.centerIn: parent
            width: slot.item ? slot.item.implicitWidth : 0
            height: slot.item ? slot.item.implicitHeight : 0

            readonly property string url: root.st ? "file://" + root.st.dir + "/Bar.qml" : ""

            // setSource, so `host` is there before the entry's own bindings run (as for the
            // widget, PluginWidgetHost.qml).
            Component.onCompleted: {
                if (slot.url !== "")
                    slot.setSource(slot.url, { host: hostApi })
            }

            onStatusChanged: {
                if (slot.status === Loader.Error)
                    console.warn("PluginBarItem: " + root.key + "/Bar.qml did not load (see the errors above)")
            }
        }

        // An entry that did not load says so, small, rather than leaving a hole in the bar.
        MaterialIcon {
            id: failText
            visible: root.loadFailed
            anchors.centerIn: parent
            name: "extension_off"
            size: 18
            color: mt.chipInk
        }
    }

    // Over the entry, the left button only: the middle and right ones go through to whatever
    // the plugin's Bar.qml makes clickable.
    MouseArea {
        id: area
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    BarTip {
        readonly property string tipText: root.loadFailed
            ? (root.plugin ? root.plugin.name : root.key) + " did not load"
            : (slot.item && typeof slot.item.tip === "string" ? slot.item.tip : "")
        shown: area.containsMouse && !root.popupOpen && tipText !== ""
        pressed: area.pressed
        text: tipText
        barPosition: root.barPosition
    }
}
