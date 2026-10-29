#!/bin/sh

# Helper for PluginService.qml: finds the desktop widget plugins and remembers each one's
# spot, monitor, on / off and settings (docs/PLUGINS.md).
#
#   plugin-state.sh scan              for every folder in the plugins folder, a line
#                                     "\036<folder>\037<its QML files>\037<target>" (the
#                                     ones of Widget.qml Bar.qml Popup.qml Service.qml that
#                                     are there, space separated; where a linked folder
#                                     really is, empty for a real one) and then its
#                                     plugin.json (nothing after the line when it has none)
#   plugin-state.sh dir               print the plugins folder
#   plugin-state.sh load <id>         print the remembered JSON (or nothing at all)
#   plugin-state.sh save <id> <json>  replace the remembered state with <json>
#   plugin-state.sh secret <path>     print a secret file the plugin's manifest names
#
# Plugins live in ${XDG_CONFIG_HOME:-~/.config}/sekaipop/plugins/<id>/ (config: you put
# them there). Their state lives in ${XDG_STATE_HOME:-~/.local/state}/sekaipop/plugins/<id>.json
# (state, not data, the same convention as usercard-state.sh), written to a temp file and
# moved into place so a crash mid-save can't leave half a file. Secrets are never written
# by this script, only read.

mode="$1"
plugins="${SEKAIPOP_PLUGINS_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/sekaipop/plugins}"
dir="${XDG_STATE_HOME:-$HOME/.local/state}/sekaipop/plugins"

# The id becomes a file name: only what PluginManifest.js accepts as one.
valid_id() {
    case "$1" in
        ''|*[!a-z0-9-]*|-*) return 1 ;;
    esac
    return 0
}

case "$mode" in
    scan)
        [ -d "$plugins" ] || exit 0
        for d in "$plugins"/*/; do
            [ -d "$d" ] || continue
            name=$(basename "$d")
            files=""
            for f in Widget.qml Bar.qml Popup.qml Service.qml; do
                [ -f "$d/$f" ] && files="${files:+$files }$f"
            done
            # Where the folder really is: a link's target (an installed repository, or a folder
            # of the user's own), or nothing for a folder that is really here.
            target=""
            [ -L "${d%/}" ] && target=$(readlink -f "${d%/}")
            printf '\036%s\037%s\037%s\n' "$name" "$files" "$target"
            [ -f "$d/plugin.json" ] && cat "$d/plugin.json"
        done
        exit 0
        ;;
    dir)
        printf '%s\n' "$plugins"
        ;;
    load)
        valid_id "$2" || exit 2
        [ -f "$dir/$2.json" ] && cat "$dir/$2.json"
        exit 0
        ;;
    save)
        valid_id "$2" || exit 2
        mkdir -p "$dir" || exit 1
        printf '%s\n' "$3" > "$dir/$2.json.tmp" || exit 1
        mv "$dir/$2.json.tmp" "$dir/$2.json"
        ;;
    secret)
        [ -n "$2" ] && [ -f "$2" ] && cat "$2"
        exit 0
        ;;
    *)
        echo "usage: $0 scan|dir|load <id>|save <id> <json>|secret <path>" >&2
        exit 2
        ;;
esac
