-- Default variables. Override them in ~/.config/hypr/custom/variables.lua.

-- The folder inside ~/.config/quickshell that holds the shell.
qsConfig = "sekaipop"
hl.env("qsConfig", qsConfig) -- for custom files and scripts that still say $qsConfig

-- `qs -c sekaipop ipc call <target> <function>`: how every shell keybind talks to the shell.
QS = "qs -c " .. qsConfig
QS_IPC = QS .. " ipc call "

local launch = "~/.config/hypr/hyprland/scripts/launch_first_available.sh"

-- Terminal. $TERMINAL wins if you already export it; otherwise the first installed of this
-- list. It is also exported as $TERMINAL (env.lua), which the shell tries before its own list,
-- so SUPER+Enter and the shell's "open in a terminal" actions open the same one.
local terminalList = { "foot", "kitty", "alacritty", "wezterm", "ghostty", "konsole", "kgx", "xterm" }
local envTerminal = os.getenv("TERMINAL")
if envTerminal and envTerminal ~= "" then
    terminalName = envTerminal
else
    terminalName = first_available(terminalList)
end
terminal = terminalName or (launch .. " 'foot' 'kitty' 'alacritty' 'wezterm' 'konsole' 'xterm'")

-- Apps (the first one installed is launched)
fileManager = launch .. " 'dolphin' 'nautilus' 'nemo' 'thunar'"
browser = launch .. " 'google-chrome-stable' 'zen-browser' 'firefox' 'brave' 'chromium' 'microsoft-edge-stable' 'opera' 'librewolf'"
codeEditor = launch .. " 'windsurf' 'antigravity' 'code' 'codium' 'cursor' 'zed' 'zeditor' 'kate' 'gnome-text-editor' 'emacs'"
officeSoftware = launch .. " 'wps' 'onlyoffice-desktopeditors' 'libreoffice'"
textEditor = launch .. " 'kate' 'gnome-text-editor' 'emacs'"
volumeMixer = launch .. " 'pavucontrol-qt' 'pavucontrol'"
-- Same order the shell uses for its own system-monitor button.
taskManager = launch .. " 'gnome-system-monitor' 'plasma-systemmonitor --page-name Processes' 'command -v btop && " .. (terminalName or "xterm") .. " -e btop'"

-- Cursor used until the shell restores the one you picked in Settings (it does that a moment
-- after it starts). Only a fallback for a fresh install.
-- Bibata is what Arch users tend to have; Debian ships no package for it, so a machine without
-- it gets Adwaita (always there) instead of an invisible pointer until the shell restores yours.
cursorTheme = "Bibata-Modern-Classic"
cursorSize = 24
local function cursor_installed(name)
    for _, d in ipairs({ HOME .. "/.icons/", HOME .. "/.local/share/icons/", "/usr/share/icons/", "/usr/local/share/icons/" }) do
        if is_file_exists(d .. name .. "/cursors/left_ptr") or is_file_exists(d .. name .. "/index.theme") then return true end
    end
    return false
end
if not cursor_installed(cursorTheme) then cursorTheme = "Adwaita" end
