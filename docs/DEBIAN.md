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

## Tested here

Developed and checked on this machine: Debian 13.x, kernel 6.12, Intel Iris Xe, greetd +
dms-greeter, niri 26.04 + DankMaterialShell as the other desktop, Quickshell 0.3.0 (backports),
Qt 6.8.2. Checked without root: `install.sh --dry-run`, `install-deps.sh --dry-run`,
`check-deps.sh`, `luac -p` on every Lua file, `bash -n` / `sh -n` on every shell script, the
shaders rebuilt with Debian's `qsb 6.8.2` (the exact binary from `qt6-shader-baker`), and the node
test suite (same results as upstream `main`). **Not yet run on a live Hyprland on Debian** (the
machine this was ported on had no root to install the backports packages during the port): the
first real login is the remaining test, and `~/.cache/sekaipop/hypr-errors.log` plus
`qs -c sekaipop log` are where to look if it goes wrong.
