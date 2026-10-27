import QtQuick
import Quickshell
import qs.services
import qs.modules.common

// The Power flyout: eight round pills — the exact same bg as Keep Awake
// and Notifications (QuickToggle's "round" kind, built on Pill.qml) —
// that cascade out beside the phone once the phone's Power button (its side button) is
// tapped (see the Power QuickToggle in QuickPanelFace.qml — a plain
// click now, same pattern as the Edit toggle beside it).
//
// Lives OUTSIDE the phone: QuickPanel.qml positions this whole item to
// the right of PhoneBody, flat and un-tilted (unlike everything drawn on
// the phone's own 2.5D screen), and scales it by the same `fit` factor
// so the pills stay proportional to the phone at any window size. The
// screen dimming that used to live in this file is now
// PowerMenuScrim.qml, which stays inside the phone — the glass going
// dark needs to follow the phone's own tilt, the rail doesn't.
//
// Pure UI: QuickPanel.qml feeds `open` and wires the action signals to
// whatever each one should actually do; this only knows how to show and
// animate the rail. Its own implicitWidth/implicitHeight are the design-
// unit footprint QuickPanel.qml reserves window space for.
//
// The "wavy pop-up": each pill's entrance is staggered by its position
// in the column (a beat of delay per row) and, on top of the usual
// scale-and-settle pop, a sideways wiggle that decays as it lands and
// alternates up/down the rail — so the whole column ripples out like a
// wave breaking, rather than every pill sliding the same way. On top of
// that, every pill slides in from the left, the phone's direction, so
// the rail reads as spilling out of it rather than appearing from
// nowhere. Closing reverses it: the bottom pill tucks away first, then
// the wave runs back up and the pills slide back toward the phone.
Item {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    property bool open: false

    // Texels per design unit at the rail's on-screen size — the exact
    // same quantity as PhoneBody's own `renderScale`, and QuickPanel.qml
    // sets it the exact same way, for the same reason (see below).
    property real renderScale: 1

    // While open, PowerBusyService looks for a package manager or a download that
    // a reboot / shutdown would interrupt (see below: a badge, and the label turns
    // into a warning).
    // -1 = nothing selected yet; first Down lands on row 0, first Up on the last.
    property int currentIndex: -1

    // The pill under the mouse (-1 = none), and whether the last selection came from
    // the keyboard: the label follows the mouse, and the keyboard only while it is
    // the one moving. (currentIndex alone would leave a label behind once the mouse
    // has left the rail.)
    property int hoveredIndex: -1
    property bool keyNav: false
    readonly property int labelIndex: hoveredIndex >= 0 ? hoveredIndex
                                      : (keyNav ? currentIndex : -1)

    function move(delta) {
        const n = rows.length
        if (n === 0) return
            keyNav = true
            currentIndex = currentIndex < 0
            ? (delta > 0 ? 0 : n - 1)
            : (currentIndex + delta + n) % n
    }

    function trigger(i) {
        switch (i) {
            case 0: root.powerOffRequested(); break
            case 1: root.rebootRequested(); break
            case 2: root.logoutRequested(); break
            case 3: root.lockRequested(); break
            case 4: root.sleepRequested(); break
            case 5: root.hibernateRequested(); break
            case 6: root.firmwareRequested(); break
            case 7: root.systemMonitorRequested(); break
        }
        root.dismissRequested()
    }

    onOpenChanged: {
        PowerBusyService.watching = root.open
        if (root.open) {
            root.currentIndex = -1
            root.hoveredIndex = -1
            root.keyNav = false
        }
    }
    Component.onDestruction: PowerBusyService.watching = false

    signal powerOffRequested()
    signal rebootRequested()
    signal logoutRequested()
    signal lockRequested()
    signal sleepRequested()
    signal hibernateRequested()
    signal firmwareRequested()
    signal systemMonitorRequested()
    signal dismissRequested()

    // Top to bottom: Material Symbols Rounded names, in the same order
    // as the signals they trigger (power off, reboot, log out, lock,
    // sleep, hibernate, firmware, system monitor).
    readonly property var rows: [
        "power_settings_circle",
        "restart_alt",
        "exit_to_app",
        "lock",
        "moon_stars",
        "hotel",
        "settings_b_roll",
        "monitor_heart"
    ]

    // What each row does, in the same order: the label shown beside a hovered or
    // keyboard-selected pill (an icon alone doesn't tell hibernate from sleep).
    readonly property var labels: [
        "Shut down",
        "Reboot",
        "Log out",
        "Lock",
        "Sleep",
        "Hibernate",
        "Reboot to firmware",
        "System monitor"
    ]

    // One pill's footprint and the gap between row centers, both design
    // units scaled by whatever this item's own `scale` ends up being
    // (QuickPanel.qml sets it to `fit`). This is also what sizes the
    // rail's window/hit-box in QuickPanel.qml (railStaticBounds), so it
    // has to cover the *largest* a pill ever gets, not just its resting
    // size — otherwise a hovered pill's extra shadow gets clipped at
    // the window edge instead of drawn.
    //
    // Resting (elevated, unhovered): 73 (round cap) + 1 (litP's max
    // +1) + 11 (shadow's max dx: 3 + 2 + hover's 6) = 85 wide,
    // 73 + 6 (shadow's max dy: 1 + 1 + hover's 4) = 79 tall. A few
    // pixels of headroom on top of that.
    readonly property real pillWidth: 90
    readonly property real pillHeight: 82
    // (2D: 89 apart, the same pitch as the header keys, as in the flat design.)
    readonly property real rowSpacing: mt.quickFlat ? 89 : 83

    // Each pill is anchorRight (see QuickToggle.qml), so it's the RIGHT
    // edge that's actually fixed — pinned here, at QuickToggle's own
    // implicitWidth for "round" pills (74 + 5) — and the left edge
    // that spills further out, toward the phone, as a pill elevates.
    // QuickPanel.qml uses this alongside pillWidth to know how far past
    // this rail's own x = 0 a hovered pill's left edge can reach
    // (pillFixedRight - pillWidth), instead of assuming growth runs the
    // other way.
    readonly property real pillFixedRight: 79

    implicitWidth: pillWidth
    implicitHeight: rows.length > 0 ? (rows.length - 1) * rowSpacing + pillHeight : 0

    visible: opacity > 0
    opacity: root.open ? 1 : 0
    Behavior on opacity {
        NumberAnimation { duration: root.open ? 120 : 260 }
    }

    // `root` itself is what QuickPanel.qml applies the phone's own 3D
    // tilt matrix to (see PowerMenu's file comment) — the same
    // perspective transform PhoneBody's own screen content gets. But
    // unlike that content, this used to be drawn straight into the
    // window with no layer at all: a 3D transform applied directly to
    // raw (un-pre-rendered) pills samples each one's fill/text/icon at
    // a skewed angle with no supersampling to compensate, which is
    // exactly what read as blurry next to the phone's own buttons (see
    // `face`'s own layer in PhoneBody.qml — same problem, same fix).
    //
    // `canvas` is that fix: everything below is drawn flat into a
    // texture first, at `renderScale * 2` the resolution it's shown
    // at, mipmapped for the same reason PhoneBody's `face` is (the
    // tilt foreshortens the far end of the rail more than the near
    // end), then the tilt is applied to that one already-antialiased
    // texture instead of to each pill individually.
    //
    // It can't just be `root` itself that's layered, though: a hovered
    // pill's shadow — and the resting-vs-elevated pop — reach past
    // `root`'s own [0, pillWidth] box on the left (see pillWidth's own
    // comment above), and a layer clips to its item's box the same way
    // `clip: true` would. `canvas` is sized around that full reach
    // plus a flat margin for safety, offset so `content` inside it —
    // holding the actual Repeater, completely unchanged — lands its
    // own (0, 0) exactly where `root`'s used to sit, so every pill
    // ends up in the exact same screen spot as before.
    readonly property real canvasMargin: 20
    readonly property real canvasLeft: pillFixedRight - pillWidth - canvasMargin
    readonly property real canvasTop: -canvasMargin
    readonly property real canvasWidth: pillWidth + canvasMargin * 2
    readonly property real canvasHeight: root.implicitHeight + canvasMargin * 2

    Item {
        id: canvas
        x: root.canvasLeft
        y: root.canvasTop
        width: root.canvasWidth
        height: root.canvasHeight

        // Only while the menu is up (`visible` is false once it has faded out): the
        // 8-sample buffers are about 25 MB and were kept for the whole session after
        // the first open. Same samples and size while it shows, so same picture.
        layer.enabled: root.visible
        layer.smooth: true
        layer.samples: 8
        layer.mipmap: true
        // No light/heavy quality split here the way PhoneBody's own
        // layer has (see its `crisp`/`animating`) — this is a handful
        // of pills, well under a megapixel even supersampled, nowhere
        // near the cost that split exists to manage, so it's cheap
        // enough to just always draw at full quality.
        layer.textureSize: Qt.size(Math.ceil(width * root.renderScale * 2),
                                    Math.ceil(height * root.renderScale * 2))

        Item {
            id: content
            x: -root.canvasLeft
            y: -root.canvasTop

            Repeater {
                model: root.rows

                delegate: QuickToggle {
                    id: item
                    flatShadow: mt.quickFlat

                    required property string modelData
                    required property int index

                    kind: "round"
                    icon: modelData
                    // These are one-shot actions, not toggles — there's no real
                    // "on" to light them up. `elevated` locks the shadow at the
                    // ON magnitude at rest, so the whole rail already reads as
                    // popped further off the phone than an ordinary OFF pill.
                    // `hoverLights` then reveals the actual cyan/mint ON look
                    // on top of that — same reveal Edit's header button does —
                    // and `hoverElevates` pushes the shadow alone even further
                    // out while hovered, so a hovered pill visibly lifts off
                    // the rail rather than just lighting up in place.
                    elevated: true
                    hoverLights: true
                    hoverElevates: true
                    anchorRight: true
                    keyFocused: root.currentIndex === item.index
                    onHoveredChanged: {
                        if (item.hovered) {
                            root.currentIndex = item.index
                            root.hoveredIndex = item.index
                            root.keyNav = false
                        } else if (root.hoveredIndex === item.index) {
                            root.hoveredIndex = -1
                        }
                    }
                    x: 0
                    y: index * root.rowSpacing

                    // 0 = tucked back in beside the phone, 1 = popped out to its
                    // resting spot in the rail.
                    property real popT: 0

                    visible: opacity > 0.02
                    opacity: popT
                    transform: [
                        Scale {
                            origin.x: item.width / 2
                            origin.y: item.height / 2
                            xScale: 0.35 + 0.65 * item.popT
                            yScale: 0.35 + 0.65 * item.popT
                        },
                        Translate {
                            // The wave: an up/down wiggle that dies out as the
                            // pill settles, alternating direction down the
                            // column, plus a slide in from the phone's side.
                            x: (1 - item.popT) * -56
                            y: Math.sin(item.popT * Math.PI) * (1 - item.popT)
                               * (item.index % 2 === 0 ? 18 : -18)
                        }
                    ]

                    SequentialAnimation {
                        id: popAnim
                        PauseAnimation { duration: item.index * 45 }
                        NumberAnimation {
                            target: item
                            property: "popT"
                            to: 1
                            duration: 340
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.7
                        }
                    }

                    SequentialAnimation {
                        id: hideAnim
                        // Reverse order: the bottom pill tucks away first, the
                        // wave then runs back up the column.
                        PauseAnimation { duration: (root.rows.length - 1 - item.index) * 30 }
                        NumberAnimation {
                            target: item
                            property: "popT"
                            to: 0
                            duration: 160
                            easing.type: Easing.InCubic
                        }
                    }

                    Connections {
                        target: root
                        function onOpenChanged() {
                            if (root.open) {
                                hideAnim.stop()
                                popAnim.restart()
                            } else {
                                popAnim.stop()
                                hideAnim.restart()
                            }
                        }
                    }

                    // Power off (0) and Reboot (1): warn while something is still
                    // installing or downloading (the badge here, the reason in the
                    // label below).
                    readonly property bool warned: root.isWarned(item.index)

                    Rectangle {
                        visible: item.warned
                        x: item.width - 21
                        y: -3
                        width: 20
                        height: 20
                        radius: 10
                        color: "#ff9f1c"
                        border.width: 2
                        border.color: mt.colBorder
                        antialiasing: true
                        z: 5

                        Text {
                            anchors.centerIn: parent
                            text: "!"
                            color: mt.colBorder
                            font.family: mt.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.Black
                        }
                    }

                    onClicked: root.trigger(item.index)
                } // QuickToggle delegate
            } // Repeater
        } // content
    } // canvas

    function isWarned(i) {
        return i >= 0 && i <= 1 && PowerBusyService.busy
    }

    // The label: what the hovered (or keyboard-selected) pill does, or, on Power
    // off / Reboot while something is installing, what it would cut off.
    //
    // On the far side of the pill from the phone. It used to be drawn on the phone's
    // side, inside `canvas`, whose layer clips to its box, so only a sliver of it
    // showed, over the phone's edge. Out here it is outside `canvas` too, so it gets
    // its own supersampled layer for the tilt, same reason as canvas's.
    // QuickPanel.qml reserves no extra room for it: the window is already as wide as
    // the turn into the Settings needs (padX), which reaches well past the rail.
    Rectangle {
        id: label
        readonly property int idx: root.labelIndex
        readonly property bool warned: root.isWarned(idx)
        // Kept while fading out, so the text doesn't blank before the plate does.
        property int shownIdx: 0
        onIdxChanged: if (idx >= 0) shownIdx = idx

        // The pill's resting box is QuickToggle's round implicitHeight (75), its
        // right edge pinned at pillFixedRight.
        x: root.pillFixedRight + 14
        y: shownIdx * root.rowSpacing + 75 / 2 - height / 2
        z: 10
        width: labelText.width + 28
        height: labelText.implicitHeight + 16
        radius: 12
        color: warned ? "#ff9f1c" : mt.chipFill
        border.width: 3
        border.color: warned ? mt.colBorder : mt.pLine
        antialiasing: true

        opacity: root.open && idx >= 0 ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation { duration: 90 }
        }

        layer.enabled: visible
        layer.smooth: true
        layer.samples: 4
        layer.mipmap: true
        layer.textureSize: Qt.size(Math.ceil(width * root.renderScale * 2),
                                    Math.ceil(height * root.renderScale * 2))

        Text {
            id: labelText
            anchors.centerIn: parent
            // The busy note can run long; wrap it rather than run off the window,
            // which only reaches about 390 design units past the rail.
            width: Math.min(implicitWidth, 300)
            wrapMode: Text.WordWrap
            text: label.warned
                  ? root.labels[label.shownIdx] + " will cut it off: " + PowerBusyService.note
                  : root.labels[label.shownIdx]
            color: label.warned ? mt.colBorder : mt.chipInk
            font.family: mt.fontFamily
            font.pixelSize: 14
            font.weight: Font.Black
        }
    }
}
