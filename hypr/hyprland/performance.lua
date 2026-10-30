-- Lite profile. Loaded by hyprland.lua only while ~/.config/sekaipop/lite exists
-- (install.sh --lite makes it; `touch` it yourself to try, delete it and `hyprctl reload`
-- to go back). Meant for integrated GPUs, older machines and laptops on battery.
--
-- Only the compositor's own effects go. The shell's surfaces (pills, cards, the phone) draw their
-- rings and hard shadows themselves, so SekaiPop looks the same; what changes is behind and
-- around app windows: no blur under transparent windows, no soft drop shadow, no dimming of the
-- unfocused ones. On an Intel/AMD iGPU these three are most of the per-frame GPU cost.
--
-- install.sh --lite also switches on the shell's own Low-end mode (Settings > Desktop,
-- `perf.lowEnd`): card-sized widget windows, effects reduced, hidden widgets unloaded.
--
-- Loaded after general.lua and before custom/ and sekaipop_overrides.lua, so anything you set in
-- custom/general.lua or in Settings > Hyprland still wins.
hl.config({
    decoration = {
        blur = { enabled = false },
        shadow = { enabled = false },
        dim_inactive = false
    }
})
