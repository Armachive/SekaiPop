# SekaiPop on Debian 13 (trixie)

This fork ([Armachive/SekaiPop](https://github.com/Armachive/SekaiPop), branch `debian`) is
[Blapples/SekaiPop](https://github.com/Blapples/SekaiPop) made to install and run on a stock
Debian 13 with `apt`. Everything the shell does is unchanged; what changed is how it gets onto
the machine, how it starts, and a few places where the scripts assumed pacman. Arch still works
with the same scripts.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/Armachive/SekaiPop/debian/get.sh | bash
```

Look first: add `--dry-run`. Laptop or integrated GPU: add `--lite` (see below). Everything
else in the main [README](../README.md) applies.

What the installer does on Debian, in order:

1. **trixie-backports.** Hyprland 0.55 (the first with the Lua config SekaiPop uses), Quickshell,
   `xdg-desktop-portal-hyprland`, `hypridle`, `hyprsunset`, `hyprpicker` and `hyprlock` are only
   there. If no source lists `trixie-backports`, the installer asks and writes
   `/etc/apt/sources.list.d/trixie-backports.list`, then `apt update`. Those packages are installed
   with `-t trixie-backports`; everything else from `main`.
2. **Packages** from the same lists as on Arch, translated (`DEB` map in `install-deps.sh`;
   `check-deps.sh` carries the same map). Things Debian does not package are fetched by hand into
   your home, never into `/usr`: the **Material Symbols Rounded** variable font (the shell's icons)
   from google/material-design-icons into `~/.local/share/fonts/`, **Google Sans Flex** (as
   upstream), and the **adw-gtk3** GTK theme from its GitHub release into `~/.local/share/themes/`.
   `songrec`, `mpvpaper` and `cloudflare-warp` have no Debian package and are skipped with a note
   (the built-in video player and the rest of the shell don't need them).
3. **The shell and the Hyprland config**, exactly as on Arch (`~/.config/quickshell/sekaipop`,
   `~/.config/hypr`). Your previous `~/.config/hypr`, if any, is moved aside and
   `./install.sh --restore` brings it back.
4. **Login screen:** `session/sekaipop-session` → `/usr/local/bin/`, `session/sekaipop.desktop` →
   `/usr/local/share/wayland-sessions/`. See [Two desktops on one machine](#two-desktops).

Check afterwards: `./check-deps.sh` (read-only; its summary prints `apt install` lines).

## Two desktops on one machine <a id="two-desktops"></a>

The login screen gets a **SekaiPop** entry next to the ones already there (Niri, GNOME, ...).
Picking it starts Hyprland with SekaiPop's config, which starts the shell. Picking the other entry
starts the other desktop with its own shell. They share your user account and nothing else:

- SekaiPop's Hyprland config lives in `~/.config/hypr`; niri's in `~/.config/niri`; DankMaterialShell's
  in `~/.config/DankMaterialShell`. None of them read the others.
- The shell is `qs -c sekaipop` (`~/.config/quickshell/sekaipop`). DMS is `dms` from
  `/usr/share/quickshell/dms`. Both are Quickshell, each its own process, started only by its own
  compositor's config (DMS by `niri.service.wants/dms.service`, SekaiPop by `hyprland/execs.lua`).
- The greeter (greetd + dms-greeter here) keeps working as it is; it lists
  `/usr/local/share/wayland-sessions` like the other session folders. Nothing in `/etc/greetd` changes.
- `sekaipop-session` refuses to start if a niri or Hyprland session is already running for your user
  (two compositors on one user bus end in a black screen), and says so on the TTY.

Known overlap: DMS installs a user unit `dms-kde-theme.path` under `default.target.wants`, which
rewrites `~/.config/kdeglobals` whenever DMS's colours change. It only fires when DMS changes
something, so it stays quiet inside a SekaiPop session; if Qt apps flip colours anyway, stop it for
the session with `systemctl --user stop dms-kde-theme.path`.

Remove the entry: `sudo rm /usr/local/bin/sekaipop-session /usr/local/share/wayland-sessions/sekaipop.desktop`.

**Never start `Hyprland` from inside the other desktop** to "have a look". Nested in niri it gets no
window, falls through to the GPU and hangs, and on the way its config exports its environment
into the systemd user session (`dbus-update-activation-environment --all` in `hyprland/execs.lua`).
The running desktop's services then inherit a dead `WAYLAND_DISPLAY` and `QT_QPA_PLATFORMTHEME=qt6ct`:
DMS drew garbage text and refused to restart until they were put back. `sekaipop-session` now
refuses to run when `WAYLAND_DISPLAY` is already set, and cleans those variables out of the user
session when Hyprland exits (as `niri-session` does for niri). If it ever happens anyway:

```bash
pkill -9 -x Hyprland
systemctl --user set-environment WAYLAND_DISPLAY=wayland-1 XDG_CURRENT_DESKTOP=niri QT_QPA_PLATFORMTHEME=gtk3
systemctl --user unset-environment HYPRLAND_INSTANCE_SIGNATURE HYPRLAND_CMD qsConfig
systemctl --user restart dms
```

(`wayland-1` is niri's socket; `ls $XDG_RUNTIME_DIR/wayland-*` shows the live one. `gtk3` is what
this machine's niri session used; `env | grep QT_QPA_PLATFORMTHEME` in a niri terminal shows yours.)

## Lite profile (`--lite`)

`install.sh --lite` creates `~/.config/sekaipop/lite`. Two things read it:

- `hypr/hyprland.lua` loads `hyprland/performance.lua` while the file exists: window blur, the soft
  drop shadow and inactive-window dimming are off. The shell draws its own rings and hard shadows,
  so SekaiPop looks the same; the saving is behind and around app windows, which on an Intel or AMD
  iGPU is most of the per-frame compositor cost.
- `settings.json` gets `perf.lowEnd: true`, the shell's own Low-end mode (Settings > Desktop):
  card-sized widget windows instead of full-screen transparent layers, reduced effects, and
  widgets hidden by Focus Mode unloaded instead of kept warm.

Back to the full look: `rm ~/.config/sekaipop/lite`, `hyprctl reload`, and switch Low-end mode off
in Settings > Desktop. `custom/general.lua` and Settings > Hyprland still override `performance.lua`
(it loads before them).

## What else differs from the Arch original

| Where | Arch | Debian 13 |
|---|---|---|
| Update badge (bar) | `checkupdates` (pacman-contrib), AUR via paru/yay | `apt-get -s upgrade` (no root; counts what the last `apt update` saw). The badge's terminal runs `sudo apt update && sudo apt full-upgrade` |
| Shaders | built once by the installer when Qt < 6.8 | the shipped `.qsb` are built with Debian's Qt 6.8 `qsb`; nothing to build. Rebuild: `qt6-shader-baker` provides `/usr/lib/qt6/bin/qsb` |
| Qt app theming | `QT_QPA_PLATFORMTHEME=kde` | `kde` only if `plasma-integration`'s plugin exists, else `qt6ct` (installed by the desktop layer), else unset. Settings > Desktop > System colours writes both |
| Cursor fallback | Bibata-Modern-Classic | Adwaita unless Bibata is installed (the shell restores your own cursor right after it starts) |
| Qt QML path | `/usr/lib/qt6/qml` | `/usr/lib/x86_64-linux-gnu/qt6/qml` (the scripts look in both) |
| Fonts | `ttf-material-symbols-variable`, `ttf-jetbrains-mono-nerd` | Material Symbols by hand, `fonts-jetbrains-mono` (no Nerd glyphs; only a fish prompt wants them) |
| `Shear` transform | Qt 6.9+ | not in 6.8 ("Shear is not a type", which stopped the shell); `PluginMeter.qml` uses the same slant as a `Matrix4x4` |
| hyprland-qtutils | pulled in by hyprland | a separate backports package; without it Hyprland shows a "missing hyprland-qtutils" popup at every start. The installer adds it |
| blueman-applet | | the `blueman` package autostarts a tray applet in every session, including niri + DMS, where it drew a blank square (DMS's icon theme has no `blueman-tray`). The installer writes `~/.config/autostart/blueman.desktop` with `Hidden=true`; delete that file to have the applet back |
| Sound at login | | Intel SOF laptops: WirePlumber can start at boot before the DSP firmware, leave the card on profile "Off" and the session with only a "Dummy Output". `scripts/system/audio-wake.sh`, run from `hyprland/execs.lua` a few seconds in, re-probes the card once if that is the case (seen on this HP Envy x360) |
| QML parser | Qt 6.11+: `short`, `long` and the other old Java reserved words are plain identifiers | Qt 6.8 still rejects them ("Expected token `identifier'"), and one such error stops the whole shell from loading. `TimerService.qml` and `ImageMath.js` were renamed around it; every QML/JS file passes Debian's own `qmllint 6.8.2` with no error. Before adding code, run that linter (package `qt6-declarative-dev-tools`): `qmllint -I /usr/lib/x86_64-linux-gnu/qt6/qml -I . $(find . -name '*.qml' -o -name '*.js')` from the `sekaipop/` folder |

## Tested here

Developed and checked on this machine: Debian 13.x, kernel 6.12, Intel Iris Xe, greetd +
dms-greeter, niri 26.04 + DankMaterialShell as the other desktop, Quickshell 0.3.0 (backports),
Qt 6.8.2. Checked without root: `install.sh --dry-run`, `install-deps.sh --dry-run`,
`check-deps.sh`, `luac -p` on every Lua file, `bash -n` / `sh -n` on every shell script, the
shaders rebuilt with Debian's `qsb 6.8.2` (the exact binary from `qt6-shader-baker`), every QML and
JS file through Debian's `qmllint 6.8.2` (no errors), and the node test suite (same results as
upstream `main`). **Not yet run on a live Hyprland on Debian** (the
machine this was ported on had no root to install the backports packages during the port): the
first real login is the remaining test, and `~/.cache/sekaipop/hypr-errors.log` plus
`qs -c sekaipop log` are where to look if it goes wrong.
