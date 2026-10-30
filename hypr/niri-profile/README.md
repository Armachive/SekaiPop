# niri profile

A niri + DankMaterialShell setup, translated for Hyprland and SekaiPop: the scrolling-column
layout, the input behaviour, the window rules, and every keybind (niri's and DMS's) with the
same keys where Hyprland and the shell have the same thing.

    install.sh --niri-profile        copies the three files to ~/.config/hypr/custom/
    cp hypr/niri-profile/*.lua ~/.config/hypr/custom/ && hyprctl reload     (by hand)

`custom/` is yours: the installer never overwrites it afterwards, so edit away.

| File | What |
|---|---|
| `general.lua` | `general.layout = "scrolling"` (Hyprland's niri-style layout) with niri's column widths (1/2 default; 1/3, 1/2, 2/3 presets), fit-not-centre, follow focus; gaps 5, border 1, rounding 5 (DMS's layout); focus follows mouse; touchpad tap and natural scroll |
| `rules.lua` | the niri window-rules: calculators, blueman-manager, Nautilus, portals, Zoom, Firefox PiP float; pavucontrol / nm-connection-editor stay tiled; Steam toasts bottom-right |
| `keybinds.lua` | the binds. Where a niri key collided with a SekaiPop default, niri's wins and the SekaiPop action moved (see the table at the top of the file) |

Keys that moved off SekaiPop's defaults: power menu Super+X (was Esc); Super+Esc now passes
every key to the window (niri's shortcuts-inhibit); text editor Super+Alt+X; game mode Super+Alt+G;
equalizer Ctrl+Super+M; Edit Desktop Super+Alt+E; focus mode Ctrl+Super+Shift+F; on-screen keyboard
Super+Alt+K; lock Super+Alt+L; sleep Ctrl+Super+Alt+L; zoom Super+Alt+-/=; record region Super+Alt+R;
next track / play-pause Super+Alt+N / P; wallpaper picker Super+W; browser Super+B.

Not translatable, left out: move-workspace-up/down (reordering workspaces), DMS's display-profile
cycle (Mod+P stays Hyprland's pin), the window-rule editor, workspace rename, reset-window-height.
The scrolling layout's own verbs (`colresize`, `swapcol`, `move +col`, `promote`, `fit`) are what
Hyprland 0.55 answers to; `hyprctl dispatch 'hl.dsp.layout("fit visible")'` tries one by hand.
