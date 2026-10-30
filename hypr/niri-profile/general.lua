-- niri profile: the layout and input behaviour of a niri + DankMaterialShell setup, on Hyprland.
-- Copy to ~/.config/hypr/custom/general.lua (install.sh --niri-profile does it). Loaded after
-- hyprland/general.lua, so these win over the defaults; Settings > Hyprland still wins over these.

hl.config({
    general = {
        -- niri's window model: columns on a strip that scrolls sideways. Hyprland's own
        -- `scrolling` layout (0.48+). Settings > Hyprland > Layout shows its options.
        layout = "scrolling",
        -- DMS's layout.kdl: gaps 5, border 1
        gaps_in = 5,
        gaps_out = 5,
        border_size = 1,
    },
    scrolling = {
        -- niri default-column-width { proportion 0.5 } and preset-column-widths 1/3, 1/2, 2/3
        -- (Mod + R cycles them, like niri's switch-preset-column-width)
        column_width = 0.5,
        explicit_column_widths = "0.33333, 0.5, 0.66667",
        -- center-focused-column "never": scroll just enough to show the focused column
        focus_fit_method = 1,
        follow_focus = true,
        -- one window on a workspace is still a half-width column, as in niri
        fullscreen_on_one_column = false,
        direction = "right",
    },
    decoration = {
        -- DMS window-rule: geometry-corner-radius 5
        rounding = 5,
    },
    input = {
        -- focus-follows-mouse (hover-focus.kdl)
        follow_mouse = 1,
        numlock_by_default = true,
        touchpad = {
            -- niri: tap, natural-scroll
            tap_to_click = true,
            natural_scroll = true,
        },
    },
    binds = {
        -- niri's Mod + wheel changes workspace without stopping on an empty one
        allow_workspace_cycles = true,
        scroll_event_delay = 150,   -- niri cooldown-ms=150
    },
    gestures = {
        -- hot-corners { off }
        -- (Hyprland has none by default; nothing to switch off)
    },
})
