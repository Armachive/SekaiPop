# Idle times: lock, screen off, sleep

After how long without input the screen locks, the screen turns off, and the machine
suspends or hibernates, each of them optional. Issue
[#101](https://github.com/Blapples/SekaiPop/issues/101).

## Using it

- **Settings > General > Idle & sleep:**
  - *Lock after*: 0 to 120 minutes, 0 is *Never*. Default 5.
  - *Screen off after*: 0 to 120 minutes, 0 is *Never*. Default 10.
  - *Sleep after* (*Hibernate after*): 0 to 240 minutes in steps of 5, 0 is *Never*. Default 15.
  - *Sleep by*: *Suspend* (the default) or *Hibernate*.
- The defaults are the times the shipped `hypridle.conf` always had.
- Each time counts from the last input, on its own: the screen can go off before the lock,
  and the machine can sleep with the lock set to *Never*. Sleeping still locks first
  (`before_sleep_cmd`), so you never wake to an open desktop.
- Keep Awake (Quick Panel), a video playing in a browser or player, and any app holding a
  Wayland idle inhibitor keep all three from happening.
- Hibernate needs a swap at least as big as your memory, and resume from it set up. When
  logind says the machine can't hibernate, the *Sleep by* note says so.
- From a script (minutes, 0 = never):

      qs -c sekaipop ipc call options set idle.lock 10
      qs -c sekaipop ipc call options set idle.screenOff 0
      qs -c sekaipop ipc call options set idle.sleep 30
      qs -c sekaipop ipc call options set idle.sleepAction hibernate
      qs -c sekaipop ipc call idle status
      qs -c sekaipop ipc call idle link

- Presets never change these. They are about this machine, not about how the desktop looks.

## How it works

hypridle still does the waiting, because it already honours every reason to stay awake:
Keep Awake's systemd idle inhibitor, the `org.freedesktop.ScreenSaver` inhibits browsers
send, and Wayland's idle inhibitors. Quickshell's own idle monitor only sees the last of
those.

The shell writes what hypridle waits for to `~/.config/sekaipop/idle.conf`, and the
shipped `~/.config/hypr/hypridle.conf` reads it with `source =`. hypridle reads its
config only when it starts, so a change restarts it. The old hypridle is stopped first,
so the new one can take over the ScreenSaver interface, and a hypridle running as a
systemd user service is restarted by systemd. The write waits about a second after the
last change, so holding a stepper's + key doesn't restart hypridle on every step. A
hypridle that isn't running isn't started; the section says so instead.

`idle.conf` is the shell's file: it is written again whenever the times change (and at
startup, when it doesn't match them), so edits made in it don't last.

## An install from before this

`hypridle.conf` is in `~/.config/hypr`, which Update now doesn't touch. One from before
this has its own `listener { }` blocks and doesn't read `idle.conf`, so the times in the
Settings would do nothing. The section then shows **Use these times**, which:

- keeps a copy of `hypridle.conf` as it was, once, as `hypridle.conf.sekaipop-bak`;
- comments out its `listener { }` blocks (each line starts with `# sekaipop-idle: `), so the
  two sets of times can't both run;
- adds `source = ~/.config/sekaipop/idle.conf` (the full path) at the end, and restarts hypridle.

The `general { }` block and any other lines of yours stay. A `hypridle.conf` that is a
symlink (a dotfiles repo) isn't edited: the message names the line to add. With no
`hypridle.conf` at all, the button makes one with the shipped `general { }` block.

Running install.sh again does the same by replacing the whole Hyprland config (your old
one is kept, see `hypr/README.md`). install.sh also writes `idle.conf` with the default
times when there is none yet, so the lock works even before the shell has started once,
and restarts hypridle.

## Where it lives

- `services/IdleService.qml`: the four settings, the debounced write, `link()`, and the
  status the section shows (`linked`, `running`, `canHibernate`). `shell.qml` reads
  `IdleService.ready` so it exists from the start.
- `scripts/system/idle-config.sh`: `status`, `write`, `link`, `restart`. The screen-off
  command is Lua (`hl.dsp.dpms`) with `hyprland.lua`, and `dpms off` / `on` with
  `hyprland.conf`.
- `services/SettingsService.qml`: `idle.lock`, `idle.screenOff`, `idle.sleep`,
  `idle.sleepAction`. `services/DesktopPresetService.qml`: `idle.` is in `keepPrefix`.
- `modules/sekai/settings/SettingsPageGeneral.qml`: the *Idle & sleep* section.
- `hypr/hypridle.conf`: the `general { }` block and the `source =` line, no listeners.
- `tests/idle-test/idle_test.js`: the script against a throwaway config folder, with
  stand-ins for hypridle, and the wiring around it.
