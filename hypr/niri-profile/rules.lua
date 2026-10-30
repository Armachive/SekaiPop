-- niri profile: the window rules from a niri config, as Hyprland window rules.
-- Copy to ~/.config/hypr/custom/rules.lua. Loaded after hyprland/rules.lua.

-- open-floating true
for _, c in ipairs({ "^org\\.gnome\\.Calculator$", "^gnome-calculator$", "^galculator$",
                     "^blueman-manager$", "^org\\.gnome\\.Nautilus$", "^xdg-desktop-portal$", "^zoom$" }) do
    hl.window_rule({ match = { class = c }, float = true })
end
hl.window_rule({ match = { class = "firefox$", title = "^Picture-in-Picture$" }, float = true })

-- open-floating false: niri kept these tiled (SekaiPop's defaults float them)
for _, c in ipairs({ "^gnome-control-center$", "^pavucontrol$", "^org.pulseaudio.pavucontrol$", "^nm-connection-editor$" }) do
    hl.window_rule({ match = { class = c }, float = false })
end

-- Steam's notification toasts: bottom-right, never take focus
hl.window_rule({ match = { class = "^steam$", title = "^notificationtoasts_\\d+_desktop$" }, float = true })
hl.window_rule({ match = { class = "^steam$", title = "^notificationtoasts_\\d+_desktop$" }, no_initial_focus = true })
hl.window_rule({ match = { class = "^steam$", title = "^notificationtoasts_\\d+_desktop$" }, move = { "(monitor_w-window_w-10)", "(monitor_h-window_h-10)" } })
