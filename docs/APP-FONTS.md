# App fonts: the font of GTK, Qt and KDE apps

The font your apps use, and their monospace font, picked in the shell and kept. Issue
[#98](https://github.com/Blapples/SekaiPop/issues/98). The shell's own font is not this:
it comes with the shell's theme.

## Using it

- **Settings > Desktop > App fonts:**
  - *Font*: type part of a name and pick it from the matches under the field, or type the
    whole name and press Enter. *Size*: 6 to 24 pt.
  - *Monospace*: the same, for terminals and code editors that follow the system's
    monospace font. Its matches are the fonts fontconfig calls monospaced; the full name of
    any other font works too. *Monospace size*: 6 to 24 pt.
  - *Use the system's* (once something is picked): stop putting the fonts back at start.
- Open apps change at once: GTK apps, KDE apps and plain Qt apps alike.
- A font picked here is saved, and put back at every start if something else changed it in
  the meantime (another settings tool, a theme switcher, a dotfiles sync).
- Until a font is picked here, nothing is written: the section shows what GTK has now.
- From a script:

      qs -c sekaipop ipc call fonts ui "Noto Sans" 10
      qs -c sekaipop ipc call fonts mono "JetBrains Mono" 10
      qs -c sekaipop ipc call fonts status
      qs -c sekaipop ipc call fonts forget

- Presets never change these.

## Why a font set by hand seemed to reset

Each kind of app reads its font from a different place, and a font set in the wrong one
is ignored rather than lost:

| Apps | Read from | Not from |
|---|---|---|
| GTK 3 / 4 on Wayland | GNOME's `font-name` / `monospace-font-name` (dconf) | `gtk-font-name` in `~/.config/gtk-3.0/settings.ini`, which only apps that never ask GNOME's settings read |
| Qt and KDE, with `QT_QPA_PLATFORMTHEME=kde` (what SekaiPop's Hyprland config sets) | `~/.config/kdeglobals`: `[General]` `font`, `menuFont`, `toolBarFont`, `smallestReadableFont`, `fixed`, and `[WM]` `activeFont` | `[Fonts]` in `qt6ct.conf`: qt6ct isn't loaded at all then |
| Qt, with `QT_QPA_PLATFORMTHEME=qt6ct` / `qt5ct` | `[Fonts]` `general` / `fixed` in `qt6ct.conf` / `qt5ct.conf` | `kdeglobals` |

So a font set in qt6ct under SekaiPop's config never reaches a Qt app, and one written to
`settings.ini` is overridden by dconf in most GTK apps. The section writes all of them.
`app-fonts.sh check` (below) prints which one this session uses and what each place holds.

## What is written

`scripts/theming/app-fonts.sh set ui|mono <family> <size>`, only these keys (every other
line of those files stays; a file that is a symlink is left alone and the key to set is
named):

- UI font: GNOME's `font-name` and `document-font-name` (`Family Size`), `gtk-font-name` in
  `gtk-3.0/settings.ini` and `gtk-4.0/settings.ini`, `kdeglobals` `[General]` `font`,
  `menuFont`, `toolBarFont`, `smallestReadableFont` (two points smaller, at least 6) and
  `[WM]` `activeFont`, and `general` in qt5ct / qt6ct.
- Monospace: GNOME's `monospace-font-name`, `kdeglobals` `fixed`, and `fixed` in qt5ct / qt6ct.
- `kdeglobals` is written when Qt is set to the kde platform theme, or KDE is installed or
  set up here. `qt5ct.conf` / `qt6ct.conf` when the file exists or the tool is installed.
- Qt fonts are written the way `QFont::toString()` does: the Qt 6 form for `kdeglobals` and
  qt6ct (`Family,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1`), the Qt 5 form for qt5ct
  (`Family,10,-1,5,50,0,0,0,0,0`).
- Then the signals: `org.kde.KDEPlatformTheme.refreshFonts` on `/KDEPlatformTheme`, which
  plasma-integration's font cache reloads on (`kfontsettingsdata.cpp`), and
  `org.kde.KGlobalSettings.notifyChange(1, 0)` (FontChanged) for KDE Frameworks 5 apps. GTK
  follows dconf by itself; qt5ct / qt6ct watch their folder.

A name is refused when it isn't installed (`fc-list`) or holds a comma, a quote, a
backslash or `=`, since it goes into a dconf string, a KDE font string and a quoted
QSettings value. A size outside 6 to 72 is refused too. A refused font isn't saved.

## Where it lives

- `services/AppFontService.qml`: the installed families, what GTK has now, the saved choice
  (`appFonts.ui`, `appFonts.uiSize`, `appFonts.mono`, `appFonts.monoSize`; `""` / `0` is
  "not picked"), the start-up check, `matches()` (names that start with the text first, then
  names that contain it) and `exact()`. Sizes are written half a second after the stepper
  stops. `shell.qml` reads `AppFontService.ready` so it exists from the start.
- `scripts/theming/app-fonts.sh`: `list ui|mono`, `get`, `set`, `check`.
- `modules/sekai/settings/SettingsPageDesktop.qml`: the *App fonts* section, after *Icons &
  cursor*. `SettingText.qml` gained `edited` (every keystroke) and `reset()`.
- `services/DesktopPresetService.qml`: `appFonts.` is in `keepPrefix`.
- `tests/app-fonts-test/app_fonts_test.js`: the script against a throwaway config folder,
  with a file-backed dconf, a small `fc-list` and a logging `dbus-send`, and the search.
