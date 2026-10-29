#!/bin/sh
# Runs scripts/state/plugin-state.sh against a throw-away config and state folder: scanning
# the plugins folder, saving and loading a plugin's state, refusing an id that is not one,
# and reading a secret file. Needs nothing but sh.
#   sh tests/plugin-test/plugin_state_test.sh
here=$(cd "$(dirname "$0")/../.." && pwd)
t=$(mktemp -d) && trap 'rm -rf "$t"' EXIT
fail=0
ok()  { printf '  ok   %s\n' "$1"; }
bad() { printf '  FAIL %s\n' "$1"; fail=1; }
expect() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (wanted '$3', got: $(echo "$2" | tr '\n' ' '))" ;; esac; }

export XDG_CONFIG_HOME="$t/config" XDG_STATE_HOME="$t/state"
unset SEKAIPOP_PLUGINS_DIR
S="sh $here/scripts/state/plugin-state.sh"

[ -z "$($S scan)" ] && ok "scan: no plugins folder, no output" || bad "scan printed something with no folder"
expect "dir: the XDG config folder" "$($S dir)" "$t/config/sekaipop/plugins"

p="$t/config/sekaipop/plugins"
mkdir -p "$p/alpha" "$p/empty"
printf '{\n  "id": "alpha"\n}\n' > "$p/alpha/plugin.json"
touch "$p/stray-file"
out=$($S scan)
expect "scan: a record per folder" "$out" "$(printf '\036alpha')"
touch "$p/alpha/Widget.qml" "$p/alpha/Popup.qml" "$p/alpha/notes.txt"
expect "scan: the folder's QML files ride on its line" "$($S scan)" "$(printf '\036alpha\037Widget.qml Popup.qml\n')"
expect "scan: an empty folder lists no files, and no link target" "$($S scan)" "$(printf '\036empty\037\037\n')"
mkdir -p "$t/elsewhere/linked" && printf '{"id":"linked"}\n' > "$t/elsewhere/linked/plugin.json" && ln -s "$t/elsewhere/linked" "$p/linked"
expect "scan: a linked folder says where it really is" "$($S scan)" "$(printf '\036linked\037\037%s\n' "$t/elsewhere/linked")"
rm "$p/linked"
expect "scan: the manifest follows, newlines kept" "$out" '"id": "alpha"'
expect "scan: a folder without plugin.json is listed (so it is reported)" "$out" "$(printf '\036empty')"
case "$out" in *stray-file*) bad "scan: a plain file is not a plugin" ;; *) ok "scan: a plain file is not a plugin" ;; esac

[ -z "$($S load alpha)" ] && ok "load: nothing saved yet, no output" || bad "load printed something before a save"
$S save alpha '{"shown":true}' && expect "save then load" "$($S load alpha)" '{"shown":true}'
[ -f "$t/state/sekaipop/plugins/alpha.json" ] && ok "state lives in XDG_STATE_HOME/sekaipop/plugins" || bad "state file not where documented"
[ ! -e "$t/state/sekaipop/plugins/alpha.json.tmp" ] && ok "no temp file left" || bad "temp file left behind"

for id in "../x" "A" "-x" "" "a/b"; do
    $S save "$id" '{}' 2>/dev/null; rc=$?
    [ "$rc" = 2 ] && ok "save refuses id '$id'" || bad "save accepted id '$id' (rc $rc)"
done
[ -z "$(find "$t/state" -name '*x*')" ] && ok "nothing written for a bad id" || bad "a bad id wrote a file"

printf 's3cret\n' > "$t/token"
expect "secret: reads the file" "$($S secret "$t/token")" "s3cret"
[ -z "$($S secret "$t/missing")" ] && ok "secret: a missing file is empty" || bad "secret printed something for a missing file"

SEKAIPOP_PLUGINS_DIR="$t/elsewhere" expect "SEKAIPOP_PLUGINS_DIR overrides the folder" "$(SEKAIPOP_PLUGINS_DIR="$t/elsewhere" $S dir)" "$t/elsewhere"

[ "$fail" = 0 ] && echo "plugin_state_test: all checks passed"
exit "$fail"
