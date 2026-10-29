# Plugins

A plugin is a desktop widget, an entry in the bar, or both, that lives in its own folder, usually
its own repository, and plugs into the shell. It is for a widget that only makes sense for you: one that shows your own
self-hosted app, needs its own API token, or would never belong in SekaiPop itself (issue #30).

The shell does everything about **where** a widget is: placing it, dragging it, which monitor,
copies on other monitors, on / off, Desktop Focus Mode, the shell scale, the pop in and out, its
picture on the Edit Desktop shelf, and desktop presets. The same goes for a bar entry: its place
in the bar, every bar edge and style, its pill, and the popup under it. The plugin only **draws**
(see [A bar entry](#a-bar-entry)).

> **Trust.** A plugin's QML runs with the shell's full rights: it can run programs and read your
> files. Install a plugin only if you would run the same code as a script of your own. The shell
> does not sandbox plugins and never downloads them.

## Installing one

1. Put its folder in `~/.config/sekaipop/plugins/` (or `$XDG_CONFIG_HOME/sekaipop/plugins/`),
   for example with `git clone`. The folder name is the plugin's id.
2. `qs -c sekaipop ipc call plugins reload` (or restart the shell).
3. Right-click the desktop, **Edit Desktop**, and click the plugin's tile on the shelf. It sits
   after the built-in widgets.

**Settings > Desktop > Plugins** lists every plugin installed, says whether each one is on the
desktop and which secrets it found, shows the folders that did not load and why, and opens a
plugin to change its settings. It has **Reload** and **Open the folder** too. A selected plugin
widget in Edit Desktop has a **Settings** key that opens it there (docs/PLUGIN-SETTINGS.md).

To update a plugin, `git pull` in its folder and reload. To remove it, delete the folder. Its saved
state (spot, on / off, settings) stays in `~/.local/state/sekaipop/plugins/<id>.json` until you
delete that too.

A folder that is not a working plugin is skipped, never loaded half-broken. The shell sends one
notification saying why; `ipc call plugins list` and the Plugins card in Settings show it again.

### Commands

```sh
qs -c sekaipop ipc call plugins list                   # every plugin, on / off, and why one was skipped
qs -c sekaipop ipc call plugins reload                 # look in the folder again, read secret files again
qs -c sekaipop ipc call plugins toggle <id>            # also: show <id>, hide <id>
qs -c sekaipop ipc call plugins set <id> <key> <value> # change a setting
qs -c sekaipop ipc call plugins resetPosition <id>     # if it ends up off-screen
qs -c sekaipop ipc call plugins settings <id>          # open Settings > Desktop > Plugins on it
qs -c sekaipop ipc call plugins bar <id> on            # its bar entry: on, off or toggle
qs -c sekaipop ipc call plugins popup <id>             # open / close its popup (for a keybind)
qs -c sekaipop ipc call desktopedit movewidget plugin:<id> DP-2
```

## Writing one

The smallest complete plugin is [`examples/plugins/hello-clock/`](../examples/plugins/hello-clock/),
a desktop widget; [`examples/plugins/hello-bar/`](../examples/plugins/hello-bar/) is the smallest
bar entry, with a popup and a service. Copy one and change it. A plugin is `plugin.json` and the
QML files of what it draws:

```
my-widget/
  plugin.json   what it is, which plugin api it was written for, its settings and secrets
  Widget.qml    the desktop widget (optional when it has a bar entry)
  Bar.qml       what its bar entry draws (needs `bar` in plugin.json)
  Popup.qml     the card under the bar entry (optional; ignored without Bar.qml)
  Service.qml   one shared poller for all of the above (optional)
```

A plugin needs at least `Widget.qml`, or `Bar.qml` with `bar`. One that has `bar` without a
`Bar.qml`, or a `Bar.qml` its manifest does not declare, is skipped with a message saying so.

It can have any other files beside those (more QML files, pictures). `Widget.qml` imports a
sibling `Card.qml` as `Card {}`, as QML always does, and `host.path("icon.png")` is the full
path of a file of its own.

### plugin.json

```json
{
    "id": "my-widget",
    "name": "My Widget",
    "version": "1.0.0",
    "api": 1,
    "description": "One line about it.",
    "icon": "dns",
    "frame": true,
    "cloneable": true,
    "settings": { "url": "https://example.org", "refreshMinutes": 5, "compact": false },
    "settingsInfo": {
        "url": { "label": "Server address", "description": "Where your status page lives." },
        "refreshMinutes": { "label": "Check every", "min": 1, "max": 60, "unit": "minutes" }
    },
    "secrets": { "token": { "env": "MY_WIDGET_TOKEN", "file": "~/.config/my-widget/token" } }
}
```

| Field         | Required | What it is                                                                                                                                                           |
| ------------- | -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `id`          | yes      | The folder's name, repeated: lower case letters, digits and `-`, at most 40. It is a file name and an ipc argument, so it is checked.                                  |
| `name`        | yes      | The title on the shelf.                                                                                                                                              |
| `version`     | yes      | The plugin's own version, as a string. Shown by `plugins list`.                                                                                                       |
| `api`         | yes      | The plugin interface it was written for. This shell speaks `1`. A plugin for an api the shell does not speak is skipped with a message saying which side to update. |
| `description` | no       | One line.                                                                                                                                                             |
| `icon`        | no       | A [Material Symbols](https://fonts.google.com/icons) name for the shelf tile. Default `extension`.                                                                    |
| `frame`       | no       | `true` (default): the shell draws its card around the widget (outline, ring, surface, shadow), like the built-in cards. `false`: the widget draws everything.          |
| `cloneable`   | no       | `true` (default): the widget can be on several monitors at once, each copy with its own spot. `false`: one monitor, and adding it on another moves it there.          |
| `settings`    | no       | `name: default`. A default is a string, a number or `true` / `false`, and its type is the setting's type.                                                            |
| `settingsInfo` | no      | How Settings draws each setting: a label, a range, choices. See [How settings are shown](#how-settings-are-shown).                                                    |
| `groups`      | no       | The order of the group headings in Settings, as a list of names.                                                                                                     |
| `bar`         | no       | `{ "label", "icon" }`: the plugin has an entry in the bar (`Bar.qml`). `label` and `icon` (Material Symbols) name it in Settings > Bar and on Edit Desktop's BAR tab; they default to `name` and `icon`. |
| `secrets`     | no       | `name: { env, file }`. Where a secret is read from: the environment variable first, then the file. `~/` is your home; a relative path is inside the plugin's folder. |

### Widget.qml

```qml
import QtQuick
import Quickshell          // and Quickshell.Io etc.: Quickshell's own modules work

Item {
    required property var host

    implicitWidth: 240     // design pixels; the shell scale is applied around it
    implicitHeight: 120

    Text {
        anchors.centerIn: parent
        text: host.settings.url
        color: host.theme.pInk
        font.family: host.theme.fontFamily
    }
}
```

- **Declare `required property var host`.** The shell hands it over as the widget is made, before
  any of the widget's own bindings run.
- **Its size** is `implicitWidth` x `implicitHeight`, in design pixels. It can change; the card
  follows. (The shell keeps it between 24 and 1600 x 1200.)
- **It cannot import the shell's own modules.** `import qs.services` and the like only resolve
  inside the shell's folder, which is on purpose: `host` and the manifest are the whole interface,
  so the shell can change everything else without breaking a plugin. Qt's and Quickshell's modules
  work as usual.
- **Clicks**: anything the widget makes clickable (a `MouseArea`, a button) keeps its clicks. The
  rest of the card is the shell's handle for dragging, on an unlocked desktop and in Edit Desktop.
  In Edit Desktop a click first selects the widget, after which it works as it does on the desktop
  (`host.selected` says when).
- **Do work only while it is wanted.** Run timers and fetches while `host.working` is true. It is
  false while the widget is hidden by Focus Mode or switched off.

### The host object

Everything the widget gets from the shell.

| Name                       | What it is                                                                                                       |
| -------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| `apiVersion`               | The plugin api the shell speaks (`1`).                                                                           |
| `id`                       | The plugin's id.                                                                                                 |
| `name`                     | Its name, from the manifest.                                                                                     |
| `version`                  | Its version, from the manifest.                                                                                  |
| `dir`                      | Its folder, as a full path.                                                                                      |
| `path(rel)`                | `dir + "/" + rel`. For a picture: `source: "file://" + host.path("logo.png")`.                                   |
| `theme`                    | The theme of the monitor it is on. It changes with the theme; bind to it, don't copy it. The names promised are below. |
| `settings`                 | The settings: the manifest's defaults with the user's values on top. A new object whenever one changes.          |
| `setSetting(key, value)`   | Changes one and saves it. Returns `false` for a key the manifest does not declare or a value of the wrong type.  |
| `reloadSecrets()`          | Reads the secret files again, as Settings' **Reload** does: for a widget's own "check again" once the user has put a token in place. `secrets` changes when they arrive. An environment variable stays the one the shell started with. |
| `secrets`                  | The secrets, by name: a string, empty when not found. A file secret arrives a moment after start.                |
| `screenName`               | The monitor it is on (`DP-1`).                                                                                   |
| `scale`                    | That monitor's shell scale. The widget is drawn in design pixels already; this is for pixel-exact images.        |
| `clone`                    | `true` for a copy on another monitor. Copies share settings; only their spot differs.                            |
| `working`                  | On screen, or about to be. Poll only while it is true.                                                           |
| `service`                  | The plugin's `Service.qml`, made once and shared by every surface (see [A service](#a-service)); `null` without one. |
| `wanted`                   | Which of the plugin's surfaces are showing anywhere, a list of `"widget"`, `"bar"` and `"popup"`.                 |
| `editing`                  | Edit Desktop is open on its monitor.                                                                             |
| `selected`                 | It is the widget selected in Edit Desktop.                                                                       |

Theme names that are promised (they are the ones the built-in cards use; others exist but may be
renamed). A desktop widget sits on the card family (`p…`); a bar entry and a popup sit on the bar
family, the colours of the bar and of its popups:

<!-- theme-names -->
- Surfaces and ink on the card: `pSurface`, `pSurfaceHover`, `pInk`, `pInkSub`, `pLine`
- Surfaces and ink in the bar and its popups: `surface`, `surfaceHover`, `surfaceDivider`, `ink`,
  `inkSub`, `line`, `lineShadow`, `ringWhite`, `surfaceRing`
- A status that wants a look but is not an error: `warnFill` (the same amber in every palette,
  with `colBorder` ink on it)
- Keys drawn like the shell's own (outline, ring, fill, hard shadow): `pSurfaceDivider` (an idle
  key's fill), `pRingWhite` (the ring inside a key), `pSurfaceRing` (a housing's pale ring),
  `pLineShadow` (the hard shadow)
- Chips and accents: `chipFill`, `chipInk`, `accentCyan`, `accentMint`, `colBorder`
- Light or dark: `dark`
- Type: `fontFamily`, `fontStyleBold`, `iconFont`
- Shape: `borderWidth`, `radiusOuter`, `shadowOffset`
<!-- /theme-names -->

### Settings and secrets

Settings are for things the user may want to change: a URL, an interval, a style. The shell keeps
them, per plugin, in its state file. They change by the widget's own `host.setSetting()` or by
`ipc call plugins set <id> <key> <value>` (the value is turned into the setting's type). A setting
the plugin stops declaring, or whose type changes, falls back to the default.

### How settings are shown

Settings > Desktop > Plugins draws a form for every plugin from its `settings`, with the shell's
own controls. A setting with nothing but its default still gets one:

| The default is   | Its control                                                   |
| ---------------- | ------------------------------------------------------------- |
| a string         | a text field                                                  |
| a number         | a stepper (- and +, by 1)                                     |
| `true` / `false` | a toggle                                                      |

Its label is the key split into words (`refreshMinutes` reads "Refresh minutes"), with the key
itself under it. `settingsInfo` makes it better. Every field is optional and works on its own:

```json
"settingsInfo": {
    "url": { "label": "Server address", "description": "Where your status page lives.", "group": "Connection" },
    "refreshMinutes": { "label": "Check every", "min": 1, "max": 60, "step": 1, "unit": "minutes", "group": "Connection" },
    "style": { "label": "Style", "choices": [{ "value": "cards", "label": "Cards" }, "list", "dots"], "group": "Look" },
    "notes": { "multiline": true }
},
"groups": ["Connection", "Look"]
```

| Field         | For             | What it does                                                                                    |
| ------------- | --------------- | ----------------------------------------------------------------------------------------------- |
| `label`       | any             | The name shown instead of the key.                                                              |
| `description` | any             | One line under the name.                                                                        |
| `group`       | any             | A heading to put it under. Headings follow `groups`, then any others in the order they appear; ungrouped settings come last. |
| `min`, `max`  | number          | Both given: a slider instead of the stepper.                                                    |
| `step`        | number          | How far one move goes. Default 1.                                                               |
| `unit`        | number          | Said after the value ("15 minutes").                                                            |
| `choices`     | string          | Chips to pick one from instead of a text field. A choice is `{ "value", "label" }`, or a plain string that is both. |
| `multiline`   | string          | A taller field, for more than a line.                                                           |

`settingsInfo` only describes; the type of a setting is still its default's, and a value is
never rewritten to fit: one outside `min` / `max` or not in `choices` is shown as it is. A field
that is wrong for its setting (a range on a string, say) is left out and the rest kept, so a
mistake there never stops a plugin from loading. An older shell ignores both fields.

**Secrets (API tokens, passwords) are never settings.** Declare them under `secrets`. The shell
reads them from the environment or from a file you keep, and never writes them anywhere: they are
not in the state file and not in a desktop preset. Settings says, per secret, whether it was
found and where (the variable's name or the file's path), and never shows the value. A file put in
place while the shell runs is read again by the card's **Reload**; an environment variable has
to be there when the shell starts.

## A bar entry

A plugin whose manifest has `bar` puts an entry in the bar: `Bar.qml` draws what is inside it,
and `Popup.qml`, when there is one, is the card that opens under it on a left click.
[`examples/plugins/hello-bar/`](../examples/plugins/hello-bar/) is the smallest one.

**The shell owns where and when**, as it does for a desktop widget:

- **The entry is one more module of the bar**, `plugin:<id>`. Settings > Bar > Modules lists it
  after the built-in ones, marked as a plugin, with a key to its settings, and Edit Desktop's BAR
  tab moves it between zones, takes it off and puts it back, per monitor too. It is **off until
  you turn it on** there (or with `ipc call plugins bar <id> on`). A newly installed entry goes at
  the end of the right zone.
- **The shell draws the pill**: the housing the status and weather pills use (outline, ring,
  chip fill, hard shadow), a flat chip in the Capsule style, held pressed while its popup is
  open. `Bar.qml` draws only what is inside, so it fits all four bar styles and every edge
  without knowing them. There is no `frame: false` for the bar.
- **The left click is the shell's**: it opens and closes the popup. `Bar.qml`'s own `MouseArea`
  may take the middle and right buttons.
- **The popup** is the face of the shell's popup card: the shell places it under the entry on any
  edge, pops it in and shrinks it back into the pill, closes it on a click away or Escape, and
  keeps one popup open at a time, built-in ones included.

### Bar.qml

```qml
import QtQuick

Item {
    required property var host
    property string tip: "Up for 3 h"   // optional: the hover tag
    property bool present: true          // optional: false takes the entry off the bar for now

    implicitWidth: label.implicitWidth   // the pill grows to fit
    implicitHeight: label.implicitHeight

    Text {
        id: label
        text: "3 h"
        color: host.bar.ink
        font.family: host.theme.fontFamily
    }
}
```

- **Its size** is `implicitWidth` x `implicitHeight`, design pixels. On a flat bar the pill is
  as tall as the others, and as wide as the content plus its padding; on a standing bar it is as
  wide as the others, and as tall as the content needs. Put the icon over the text when
  `host.bar.vertical`, as the weather pill does.
- **`present`** (optional): set it false while the entry has nothing to say (the thing it watches
  is not installed, say). The entry then takes no room, as a module that is off.
- **`tip`** (optional): the hover tag's text.
- Use `host.bar.ink` and `host.bar.inkSub` for what it draws: they are already the right ink for
  the pill it sits in, in every style and mode.

What a bar entry's `host` has on top of the names above, under `host.bar`:

| Name             | What it is                                                                         |
| ---------------- | ---------------------------------------------------------------------------------- |
| `bar.vertical`   | The bar stands on the left or right edge.                                          |
| `bar.edge`       | Which edge it is on: `"top"`, `"bottom"`, `"left"` or `"right"`.                   |
| `bar.capsule`    | The bar is in the Capsule style (the pill is a flat chip).                         |
| `bar.ink`        | The ink for the pill it sits in.                                                   |
| `bar.inkSub`     | The same, quieter.                                                                 |
| `bar.popupOpen`  | Its popup is open.                                                                 |
| `bar.hasPopup`   | The plugin has a `Popup.qml`.                                                      |

A bar entry's `host` has no `clone`, `editing` or `selected` (those are about a widget on the
desktop), and its `working` is true while the entry is on this bar.

### Popup.qml

```qml
import QtQuick

Item {
    required property var host
    implicitWidth: 320
    implicitHeight: list.implicitHeight + 32
    // ...draw on the card's face, with host.theme's bar family (surface, ink, inkSub, line)
}
```

- **Its size** is `implicitWidth` x `implicitHeight`, kept between 280 and 480 wide and at most
  `host.popup.maxHeight` tall (70 % of the screen); past that it is cut, so a long list scrolls
  inside (a `Flickable`).
- It is built the first time the popup opens, then kept: its `host.working` is true while it is
  open.
- A `keyed(event)` function on its root, when it has one, gets the keys other than Escape.

What a popup's `host` has on top of the names above, under `host.popup`:

| Name                | What it is                                                                       |
| ------------------- | -------------------------------------------------------------------------------- |
| `popup.open`        | It is open.                                                                      |
| `popup.maxHeight`   | The most it may be tall, design pixels.                                          |
| `popup.close()`     | Put the popup away, for an action that ends it (opening a page, signing in).     |

## A service

A plugin that shows the same data in several places (a widget, a bar entry on two monitors, a
popup) should fetch it once. `Service.qml` is made once per plugin, when the plugin loads, and
handed to every surface as `host.service`; they read its properties.

```qml
import QtQuick

QtObject {
    required property var host
    property int count: 0
    property Timer timer: Timer {
        running: host.working
        repeat: true
        triggeredOnStart: true
        // slowly while only the bar shows it, at the user's pace while a popup or the widget does
        interval: host.wanted.length === 1 && host.wanted[0] === "bar" ? 30000 : host.settings.seconds * 1000
        onTriggered: { /* fetch, then set count */ }
    }
}
```

Its `host` is the part of the others that is not about a surface: `apiVersion`, `id`, `name`,
`version`, `dir`, `path()`, `settings`, `setSetting()`, `secrets`, `reloadSecrets()`, plus:

- `working`: true while any surface of the plugin shows (a widget on screen, an entry on a bar,
  an open popup). Poll only while it is true.
- `wanted`: which kinds are showing, a list of `"widget"`, `"bar"` and `"popup"`. A bar entry
  alone usually wants less often than an open popup.

It has no `theme` and no monitor: a service draws nothing.

### Presets and copies

A desktop preset holds each plugin's on / off and its spot, like a built-in widget, and never its
settings. A bar entry's place is part of the bar's layout, which a preset holds like the built-in
modules'; its on / off is the plugin's own (in its state file) and stays as it is. As with built-in widgets, a preset saved before a plugin was installed switches it off
when worn.

## How it works

| File                                                         | What it does                                                                                                     |
| ------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------- |
| `sekaipop/services/PluginService.qml`                        | Finds the plugins at start-up and on `reload`, checks them, makes one `PluginState` each, the `plugins` ipc, and the bar modules the plugins add (`barModules`). |
| `sekaipop/services/PluginState.qml`                          | One plugin's spot, on / off (desktop and bar), settings and secrets, shaped like a widget's service; makes its `Service.qml` and keeps `working` / `wanted`. |
| `sekaipop/services/BarLayoutService.qml`                     | The bar's modules, the plugins' included: their place, and their on / off through `masterOn` / `setMaster`.      |
| `sekaipop/modules/sekai/bar/PluginBarItem.qml`               | A plugin's entry in the bar: the pill, the left click, the hover tag, and the bar entry's `host`.               |
| `sekaipop/modules/sekai/bar/PluginPopup.qml`                 | A plugin's popup: the shell's popup card (`SekaiPopup.qml`) with `Popup.qml` on its face, and the popup's `host`. |
| `sekaipop/modules/sekai/bar/Status_Bar.qml`, `Bar.qml`       | One `PluginBarItem` per plugin entry, placed by the layout like a built-in pill; one `PluginPopup` each, one popup open at a time. |
| `sekaipop/modules/common/functions/PluginManifest.js`        | The manifest rules (`API_VERSION`, `parse`, settings, saved state). Pure functions, tested in node.             |
| `sekaipop/modules/common/functions/PluginForm.js`            | What Settings shows of a plugin: the form, the labels, skip reasons in plain words. Pure functions, tested in node. |
| `sekaipop/modules/sekai/settings/SettingsPluginsCard.qml`    | Settings > Desktop > Plugins, with `PluginRow`, `PluginEditor`, `PluginSettingRow` and `PluginSecretRow`.          |
| `sekaipop/scripts/state/plugin-state.sh`                     | Lists the plugin folders and the QML files in each, saves and loads state, reads secret files.                   |
| `sekaipop/modules/sekai/desktopWidgets/PluginWidgetHost.qml` | The window: placement, dragging, Edit Desktop, Focus Mode, the frame, and the `host` object.                     |
| `sekaipop/shell.qml`                                         | One `PluginWidgetHost` per plugin, and one per copy on another monitor.                                          |
| `EditMode.qml`, `PresetWidgets.qml`                          | A plugin is `plugin:<id>`: the shelf (`shelfList`), adding, removing and copying, and presets (`PresetWidgets.all`). |

Because each plugin's `PluginState` has the same shape as a built-in widget's service (`loaded`,
`shown`, `posX` / `posY` / `posScale`, `screenName`, `setShown`, `setPosition`, `snapshot` /
`restore`), Edit Desktop, the monitor copies and presets handle it with the code they already
had. Nothing in them is plugin-specific beyond looking the state up.

### Changing the interface

The manifest fields and the `host` object above are a promise to plugins written elsewhere:

- **Adding** a manifest field (with a default) or a `host` property is fine at any time.
- **Renaming, removing or changing the meaning** of one is a new api: raise `API_VERSION` in
  `PluginManifest.js`, keep the old number in `SUPPORTED` for as long as reading old plugins costs
  little, and say what changed here.
- `tests/plugin-test/manifest_unit.js` checks that every `host` name and every promised theme name
  in this file exists in the code, so this document can't silently drift from the code.

### Tests

```sh
node sekaipop/tests/plugin-test/manifest_unit.js      # manifest, settings, state, wiring, the example
node sekaipop/tests/plugin-test/form_unit.js          # what Settings shows: the form, labels, skip reasons
sh sekaipop/tests/plugin-test/plugin_state_test.sh     # the state script, against a throwaway folder
node sekaipop/tests/preset-widgets-test/registry_unit.js
```
