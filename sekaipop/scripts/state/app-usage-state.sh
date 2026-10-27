#!/bin/sh

# Helper for AppSource.qml: remembers how often each app is opened from the
# Apps screen (the "Most used" order, setting launcher.order) across shell
# restarts.
#
#   app-usage-state.sh save <json>   replace the store with this JSON
#   app-usage-state.sh load          print it (nothing if never saved)
#
# Lives in ${XDG_STATE_HOME:-~/.local/state}/sekaipop/app-usage.json -- state,
# same place pinned-apps-state.sh and extras-state.sh keep theirs. The JSON is
# one argv entry, so nothing needs quoting.

mode="$1"
shift
dir="${XDG_STATE_HOME:-$HOME/.local/state}/sekaipop"
file="$dir/app-usage.json"

case "$mode" in
    save)
        mkdir -p "$dir" || exit 1
        # Written to a temp file first, so a crash can't leave half a store.
        printf '%s\n' "$1" > "$file.tmp" && mv "$file.tmp" "$file"
        ;;
    load)
        [ -f "$file" ] && cat "$file"
        exit 0
        ;;
    *)
        echo "usage: $0 save <json>|load" >&2
        exit 2
        ;;
esac
