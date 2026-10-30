-- niri profile: every bind of a niri + DankMaterialShell setup, translated for Hyprland and the
-- SekaiPop shell. Copy to ~/.config/hypr/custom/keybinds.lua (install.sh --niri-profile does it).
--
-- Where a niri key collided with a SekaiPop default, the niri key wins and the SekaiPop action
-- moves to another key (listed under "Moved SekaiPop defaults"). Settings > Hyprland > Keybinds
-- and the cheat sheet (Super + /) see all of them. QS_IPC comes from hyprland/variables.lua.
--
-- niri things with no Hyprland equivalent, left out: move-workspace-up/down (reordering
-- workspaces), cycle display profile (Mod + P), DMS window-rule editor (Mod + Shift + W),
-- workspace rename (Ctrl + Shift + R), reset-window-height (Mod + Ctrl + R).

local ipc = QS_IPC
local function sh(cmd) return hl.dsp.exec_cmd(cmd) end
local function lay(msg) return hl.dsp.layout(msg) end

-- ---------------------------------------------------------------- SekaiPop defaults that give way
for _, k in ipairs({
    "SUPER + Escape",        -- power options  -> Super + X        (niri: shortcut passthrough)
    "SUPER + X",             -- text editor    -> Super + Alt + X
    "SUPER + W",             -- browser        -> Super + B        (niri: wallpaper picker)
    "SUPER + D",             -- maximize       -> Super + F        (niri: Dopamine)
    "SUPER + F",             -- fullscreen     -> Super + Shift + F
    "SUPER + SHIFT + F",     -- focus mode     -> Ctrl + Super + Shift + F
    "SUPER + G",             -- game mode      -> Super + Alt + G  (niri: float window)
    "SUPER + M",             -- equalizer      -> Ctrl + Super + M (niri: task manager)
    "SUPER + SHIFT + E",     -- edit desktop   -> Super + Alt + E  (niri: quit session)
    "SUPER + SHIFT + N",     -- next track     -> Super + Alt + N  (niri: notepad)
    "SUPER + SHIFT + P",     -- play/pause     -> Super + Alt + P  (niri: monitors off)
    "SUPER + Minus", "SUPER + Equal",   -- zoom -> Super + Alt + Minus / Equal (niri: column width)
    "SUPER + BracketLeft", "SUPER + BracketRight", -- focus l/r -> (niri: consume / expel)
    "SUPER + K",             -- on-screen keyboard -> Super + Alt + K (niri: focus up)
    "SUPER + L",             -- lock           -> Super + Alt + L  (niri: focus right)
    "SUPER + SHIFT + L",     -- sleep          -> Ctrl + Super + Alt + L (niri: move column right)
    "SUPER + SHIFT + mouse_down", "SUPER + SHIFT + mouse_up",
    "SUPER + SHIFT + R",     -- record region  -> Super + Alt + R  (niri: preset width back)
    "SUPER + Page_Up", "SUPER + Page_Down",        -- rebound below with niri's meaning
    "CTRL + SUPER + Left", "CTRL + SUPER + Right", "CTRL + SUPER + Up", "CTRL + SUPER + Down",
    "CTRL + SUPER + SHIFT + Left", "CTRL + SUPER + SHIFT + Right",
    "CTRL + SUPER + BracketLeft", "CTRL + SUPER + BracketRight",
    "SUPER + SHIFT + Left", "SUPER + SHIFT + Right", "SUPER + SHIFT + Up", "SUPER + SHIFT + Down",
    "SUPER + Left", "SUPER + Right", "SUPER + Up", "SUPER + Down",
    "SUPER + mouse_down", "SUPER + mouse_up", "CTRL + SUPER + mouse_down", "CTRL + SUPER + mouse_up",
    "Print", "CTRL + Print",
    "SUPER + 1", "SUPER + 2", "SUPER + 3", "SUPER + 4", "SUPER + 5", "SUPER + 6", "SUPER + 7", "SUPER + 8", "SUPER + 9",
}) do pcall(hl.unbind, k) end

-- ---------------------------------------------------------------- Moved SekaiPop defaults
hl.bind("SUPER + ALT + X", sh(textEditor), { description = "Apps: Text editor" })
hl.bind("SUPER + ALT + K", sh(ipc .. "keyboard toggle"), { description = "Shell: Toggle on-screen keyboard" })
hl.bind("CTRL + SUPER + ALT + L", sh("systemctl suspend || loginctl suspend"), { locked = true, description = "Session: Sleep" })
hl.bind("SUPER + ALT + R", sh(ipc .. "region toggleRecord"), { locked = true, description = "Utilities: Record region (no sound)" })
hl.bind("SUPER + ALT + G", sh(ipc .. "gamemode toggle"), { description = "Shell: Toggle game mode" })
hl.bind("CTRL + SUPER + M", sh(ipc .. "eq open"), { description = "Shell: Toggle equalizer" })
hl.bind("SUPER + ALT + E", sh(ipc .. "desktopedit toggle"), { description = "Shell: Edit desktop" })
hl.bind("CTRL + SUPER + SHIFT + F", sh(ipc .. "focus toggle"), { description = "Shell: Toggle focus mode" })
hl.bind("SUPER + ALT + N", sh("playerctl next"), { locked = true, description = "Media: Next track" })
hl.bind("SUPER + ALT + P", sh("playerctl play-pause"), { locked = true, description = "Media: Play/pause media" })
local function zoomby(v)
    local z = hl.get_config("cursor:zoom_factor") + v
    if z > 3.0 then z = 3.0 elseif z < 1.0 then z = 1.0 end
    hl.config({ cursor = { zoom_factor = z } })
end
hl.bind("SUPER + ALT + Minus", function() zoomby(-0.3) end, { repeating = true, description = "Screen: Zoom out" })
hl.bind("SUPER + ALT + Equal", function() zoomby(0.3) end, { repeating = true, description = "Screen: Zoom in" })

-- ---------------------------------------------------------------- DMS shell keys -> SekaiPop
hl.bind("SUPER + Space", sh(ipc .. "launcherphone toggle"), { description = "Shell: Apps" })
hl.bind("SUPER + Comma", sh(ipc .. "settings toggle"), { description = "Shell: Toggle settings" })
-- Super + N (quick panel), Super + V (clipboard), Super + Tab (overview), Super + Q (close): already
-- SekaiPop's own binds with the same meaning, so they are not repeated here.
hl.bind("SUPER + SHIFT + N", sh(ipc .. "notes toggle"), { description = "Shell: Sticky notes" })
hl.bind("SUPER + W", sh(ipc .. "wallpaperpicker toggle"), { description = "Shell: Wallpaper picker" })
hl.bind("SUPER + X", sh(ipc .. "phone go power"), { description = "Session: Power menu" })
hl.bind("SUPER + ALT + L", sh(ipc .. "lock lock || loginctl lock-session"), { description = "Session: Lock screen" })
hl.bind("SUPER + H", sh(ipc .. "bar toggle"), { description = "Shell: Toggle bar" })
hl.bind("SUPER + M", sh(taskManager), { description = "Apps: Task manager" })
hl.bind("CTRL + ALT + Delete", sh(taskManager), { description = "Apps (more): Task manager" })
hl.bind("SUPER + SHIFT + Slash", sh(ipc .. "cheatsheet toggle"), { description = "Shell (more): Toggle cheatsheet" })
-- Ctrl + volume keys: the player's own volume (DMS mpris increment/decrement 3)
hl.bind("CTRL + XF86AudioRaiseVolume", sh("playerctl volume 0.03+"), { locked = true })
hl.bind("CTRL + XF86AudioLowerVolume", sh("playerctl volume 0.03-"), { locked = true })

-- ---------------------------------------------------------------- Apps
hl.bind("SUPER + B", sh("vivaldi"), { description = "Apps: Browser (Vivaldi)" })
hl.bind("SUPER + D", sh("dopamine"), { description = "Apps: Dopamine" })
hl.bind("SUPER + O", sh("obsidian"), { description = "Apps: Obsidian" })
-- Super + E (Dolphin) and Super + T (kitty) are already SekaiPop's defaults.

-- ---------------------------------------------------------------- Screenshots (niri: Print = pick, Ctrl = screen, Alt = window)
local shotdir = "mkdir -p \"$(xdg-user-dir PICTURES)/Screenshots\" && f=\"$(xdg-user-dir PICTURES)/Screenshots/Screenshot from $(date '+%Y-%m-%d %H-%M-%S').png\""
local mon = "grim -o \"$(hyprctl activeworkspace -j | jq -r '.monitor')\""
local win = "grim -g \"$(hyprctl activewindow -j | jq -r '\"\\(.at[0]),\\(.at[1]) \\(.size[0])x\\(.size[1])\"')\""
hl.bind("Print", sh(ipc .. "region screenshot || grim -g \"$(slurp)\" - | wl-copy"), { locked = true, description = "Utilities: Screenshot (pick a region)" })
hl.bind("XF86Launch1", sh(ipc .. "region screenshot"), { locked = true, description = "Utilities (more): Screenshot (pick a region)" })
hl.bind("CTRL + Print", sh(shotdir .. " && " .. mon .. " - | tee \"$f\" | wl-copy"), { locked = true, description = "Utilities: Screenshot the screen >> clipboard & file" })
hl.bind("CTRL + XF86Launch1", sh(shotdir .. " && " .. mon .. " - | tee \"$f\" | wl-copy"), { locked = true })
hl.bind("ALT + Print", sh(shotdir .. " && " .. win .. " - | tee \"$f\" | wl-copy"), { description = "Utilities: Screenshot the window >> clipboard & file" })
hl.bind("ALT + XF86Launch1", sh(shotdir .. " && " .. win .. " - | tee \"$f\" | wl-copy"))

-- ---------------------------------------------------------------- Windows and columns (scrolling layout)
hl.bind("SUPER + G", hl.dsp.window.float({ action = "toggle" }), { description = "Windows: Float/Tile" })
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }), { description = "Windows: Maximize column" })
hl.bind("SUPER + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }), { description = "Windows: Fullscreen" })
hl.bind("SUPER + Y", hl.dsp.group.toggle(), { description = "Windows: Tabbed column (group)" })
hl.bind("SUPER + SHIFT + V", hl.dsp.window.cycle_next({ floating = true }), { description = "Windows: Focus floating / tiled" })

-- focus: Mod + arrows / H J K L (H is the bar toggle, as in the DMS binds)
for key, dir in pairs({ Left = "l", Right = "r", Up = "u", Down = "d", J = "d", K = "u", L = "r" }) do
    hl.bind("SUPER + " .. key, hl.dsp.focus({ direction = dir }), { description = "Windows: Focus column / window" })
end
-- move: Mod + Shift + arrows / H J K L. Sideways moves the whole column (niri move-column),
-- up / down moves the window inside it.
for key, dir in pairs({ Left = "l", Right = "r", H = "l", L = "r" }) do
    hl.bind("SUPER + SHIFT + " .. key, lay("swapcol " .. dir), { description = "Windows: Move column left/right" })
end
for key, dir in pairs({ Up = "u", Down = "d", K = "u", J = "d" }) do
    hl.bind("SUPER + SHIFT + " .. key, hl.dsp.window.move({ direction = dir }), { description = "Windows: Move window up/down" })
end
hl.bind("SUPER + Home", lay("fit tobeg"), { description = "Windows: Show the first columns" })
hl.bind("SUPER + End", lay("fit toend"), { description = "Windows: Show the last columns" })
hl.bind("CTRL + SUPER + Home", lay("fit tobeg"), { description = "Windows (more): Show the first columns" })
hl.bind("CTRL + SUPER + End", lay("fit toend"), { description = "Windows (more): Show the last columns" })
hl.bind("CTRL + SUPER + C", lay("fit visible"), { description = "Windows: Center the visible columns" })
hl.bind("CTRL + SUPER + F", lay("colresize 1.0"), { description = "Windows: Column to full width" })
hl.bind("SUPER + R", lay("colresize +conf"), { description = "Windows: Next preset column width" })
hl.bind("SUPER + SHIFT + R", lay("colresize -conf"), { description = "Windows: Previous preset column width" })
hl.bind("SUPER + Minus", lay("colresize -0.1"), { repeating = true, description = "Windows: Column narrower" })
hl.bind("SUPER + Equal", lay("colresize +0.1"), { repeating = true, description = "Windows: Column wider" })
hl.bind("SUPER + SHIFT + Minus", hl.dsp.window.resize({ x = 1, y = -80 }), { repeating = true, description = "Windows: Window shorter" })
hl.bind("SUPER + SHIFT + Equal", hl.dsp.window.resize({ x = 1, y = 80 }), { repeating = true, description = "Windows: Window taller" })
-- consume / expel: pull the window into the column beside it, or out into its own
hl.bind("SUPER + BracketLeft", lay("move -col"), { description = "Windows: Window into the column on the left" })
hl.bind("SUPER + BracketRight", lay("move +col"), { description = "Windows: Window into the column on the right" })
hl.bind("CTRL + SUPER + SHIFT + Period", lay("promote"), { description = "Windows: Window out into its own column" })
-- wheel: Mod + Shift + wheel / sideways wheel = focus column, Mod + Ctrl + Shift = move column
for _, w in ipairs({ { "SUPER + SHIFT + mouse_down", "r" }, { "SUPER + SHIFT + mouse_up", "l" },
                     { "SUPER + mouse_right", "r" }, { "SUPER + mouse_left", "l" } }) do
    hl.bind(w[1], lay("focus " .. w[2]), { description = "Windows (more): Focus column left/right" })
end
for _, w in ipairs({ { "CTRL + SUPER + SHIFT + mouse_down", "r" }, { "CTRL + SUPER + SHIFT + mouse_up", "l" },
                     { "CTRL + SUPER + mouse_right", "r" }, { "CTRL + SUPER + mouse_left", "l" } }) do
    hl.bind(w[1], lay("swapcol " .. w[2]), { description = "Windows (more): Move column left/right" })
end

-- ---------------------------------------------------------------- Monitors
for key, dir in pairs({ Left = "l", Right = "r", H = "l", J = "d", K = "u", L = "r" }) do
    hl.bind("CTRL + SUPER + " .. key, hl.dsp.focus({ monitor = dir }), { description = "Workspaces: Focus monitor" })
    hl.bind("CTRL + SUPER + SHIFT + " .. key, hl.dsp.window.move({ monitor = dir }), { description = "Workspaces: Move column to monitor" })
end
hl.bind("CTRL + SUPER + SHIFT + Up", hl.dsp.window.move({ monitor = "u" }), { description = "Workspaces (more): Move column to monitor" })
hl.bind("CTRL + SUPER + SHIFT + Down", hl.dsp.window.move({ monitor = "d" }), { description = "Workspaces (more): Move column to monitor" })
hl.bind("SUPER + SHIFT + P", hl.dsp.dpms({ action = "disable" }), { description = "Session: Monitors off" })

-- ---------------------------------------------------------------- Workspaces (niri: up/down = next/previous)
for i = 1, 9 do
    hl.bind("SUPER + " .. i, hl.dsp.focus({ workspace = i }), { description = "Workspaces: Go to workspace" })
    hl.bind("SUPER + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }), { description = "Workspaces: Move column to workspace" })
end
for _, k in ipairs({ "SUPER + Page_Down", "SUPER + ALT + Down", "SUPER + mouse_down" }) do
    hl.bind(k, hl.dsp.focus({ workspace = "+1" }), { description = "Workspaces: Next workspace" })
end
for _, k in ipairs({ "SUPER + Page_Up", "SUPER + ALT + Up", "SUPER + mouse_up" }) do
    hl.bind(k, hl.dsp.focus({ workspace = "-1" }), { description = "Workspaces: Previous workspace" })
end
for _, k in ipairs({ "CTRL + SUPER + Down", "CTRL + SUPER + U", "CTRL + SUPER + mouse_down" }) do
    hl.bind(k, hl.dsp.window.move({ workspace = "+1" }), { description = "Workspaces: Move column to next workspace" })
end
for _, k in ipairs({ "CTRL + SUPER + Up", "CTRL + SUPER + I", "CTRL + SUPER + mouse_up" }) do
    hl.bind(k, hl.dsp.window.move({ workspace = "-1" }), { description = "Workspaces: Move column to previous workspace" })
end

-- ---------------------------------------------------------------- Session
-- Mod + Escape: let every key through to the focused window (VMs, remote desktops), as niri's
-- toggle-keyboard-shortcuts-inhibit. Press it again to come back.
hl.define_submap("passthrough", function()
    hl.bind("SUPER + Escape", function()
        if hl.get_current_submap() == "passthrough" then
            hl.dispatch(hl.dsp.submap("reset"))
            hl.dispatch(sh("notify-send -a Hyprland 'Shortcuts back on' 'Super + Escape switches them off again'"))
        else
            hl.dispatch(sh("notify-send -a Hyprland 'Shortcuts off' 'Every key goes to the window. Super + Escape brings them back'"))
            hl.dispatch(hl.dsp.submap("passthrough"))
        end
    end, { submap_universal = true, description = "Session: Pass all keys to the window" })
end)
hl.bind("SUPER + SHIFT + E", sh("sh ~/.config/quickshell/" .. qsConfig .. "/scripts/system/session-logout.sh"), { description = "Session: Log out" })
