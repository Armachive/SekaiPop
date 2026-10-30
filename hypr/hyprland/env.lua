local home_dir = os.getenv("HOME")

-- Wayland
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- Applications
local xdg_data_dirs_old = os.getenv("XDG_DATA_DIRS") or ""
hl.env("XDG_DATA_DIRS", home_dir .. "/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:/usr/local/share:/usr/share:" .. xdg_data_dirs_old)

-- Qt theming. `kde` is what Settings > Desktop > System colours needs for Dolphin and other KDE
-- apps to follow the shell's colours, but it needs KDE's platform-theme plugin
-- (plasma-integration). Without that plugin, `kde` leaves Qt apps on the bare Fusion look with
-- no icons, which is the usual state of a Debian or Fedora box that never had Plasma. So: `kde`
-- when the plugin is installed, else qt6ct when that is (the shell's System colours write both),
-- else Qt is left to its own defaults. The shell's `system-theme.sh check` says which you have.
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
local kdeTheme = false
for _, f in ipairs({
    "/usr/lib/qt6/plugins/platformthemes/KDEPlasmaPlatformTheme6.so",             -- Arch
    "/usr/lib/x86_64-linux-gnu/qt6/plugins/platformthemes/KDEPlasmaPlatformTheme6.so", -- Debian, Ubuntu
    "/usr/lib/aarch64-linux-gnu/qt6/plugins/platformthemes/KDEPlasmaPlatformTheme6.so",
    "/usr/lib64/qt6/plugins/platformthemes/KDEPlasmaPlatformTheme6.so",           -- Fedora, openSUSE
}) do
    if is_file_exists(f) then kdeTheme = true break end
end
if kdeTheme then
    hl.env("QT_QPA_PLATFORMTHEME", "kde")
    hl.env("XDG_MENU_PREFIX", "plasma-")
elseif first_available({ "qt6ct" }) then
    hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
end

-- The shell runs $TERMINAL before its own list of terminals.
if terminalName and terminalName ~= "" and not os.getenv("TERMINAL") then
    hl.env("TERMINAL", terminalName)
end

-- File chooser for the avatar / banner picker: kdialog, zenity or yad. Unset = the shell picks.
-- hl.env("SEKAIPOP_CHOOSER", "kdialog")
