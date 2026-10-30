# Login-screen entry

`install.sh` copies these two files to

    /usr/local/bin/sekaipop-session
    /usr/local/share/wayland-sessions/sekaipop.desktop

so the login screen (greetd's dms-greeter or tuigreet, SDDM, GDM, LightDM, ly) shows a
**SekaiPop** session next to whatever else is installed (Niri, GNOME, ...). Picking it starts
Hyprland with SekaiPop's config; picking the other entry starts the other desktop with its own
shell. Nothing is shared between them except your user account.

To remove the entry:

    sudo rm /usr/local/bin/sekaipop-session /usr/local/share/wayland-sessions/sekaipop.desktop

The `Hyprland` entry that the hyprland package itself installs also works (it runs the same
config), only without the name. The `Hyprland (uwsm)` entry does not: the shell's autostart
and environment live in Hyprland's config, which uwsm bypasses.
