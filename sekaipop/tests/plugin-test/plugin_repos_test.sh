#!/bin/sh
# Runs scripts/state/plugin-repos.sh against local git repositories in a throw-away folder (no
# network): looking, installing with progress, linking, checking, updating, going back,
# removing, and that nothing outside its own folders is touched.
# Run: sh plugin_repos_test.sh
here=$(cd "$(dirname "$0")/../.." && pwd)
t=$(mktemp -d "${TMPDIR:-/tmp}/plugin-repos-test.XXXXXX")
trap 'rm -rf "$t"' EXIT
fails=0
ok() { echo "  ok   $1"; }
bad() { echo "  FAIL $1"; fails=$((fails + 1)); }
expect() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (wanted '$3', got: $(echo "$2" | tr '\n' ' '))" ;; esac; }

export XDG_CONFIG_HOME="$t/config" XDG_STATE_HOME="$t/state" XDG_DATA_HOME="$t/data" XDG_CACHE_HOME="$t/cache"
unset SEKAIPOP_PLUGINS_DIR
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
S="sh $here/scripts/state/plugin-repos.sh"
repos="$t/data/sekaipop/plugin-repos"
plugins="$t/config/sekaipop/plugins"

# A plugin repository with two plugins in folders, served from a bare repository.
w="$t/work"; mkdir -p "$w/clock" "$w/weather"
printf '{"id":"clock","name":"Clock","version":"1.0.0","api":1}\n' > "$w/clock/plugin.json"; touch "$w/clock/Widget.qml"
printf '{"id":"weather","name":"Weather","version":"1.0.0","api":1,"bar":{}}\n' > "$w/weather/plugin.json"; touch "$w/weather/Bar.qml"
git -C "$w" init -q -b main && git -C "$w" add -A && git -C "$w" commit -qm one
git clone -q --bare "$w" "$t/origin.git"
url="file://$t/origin.git"

expect "paths: the repos folder" "$($S paths)" "repos=$repos"
expect "look: what is in it" "$($S look "$url" me/widgets)" "$(printf 'status=ok\n\036clock\037Widget.qml')"
[ -z "$(find "$t/cache" -name 'look.*' 2>/dev/null)" ] && ok "look: keeps nothing" || bad "look left its scratch folder"
mkdir -p "$t/empty" && git -C "$t/empty" init -q -b main && git -C "$t/empty" commit -q --allow-empty -m e && git clone -q --bare "$t/empty" "$t/empty.git"
expect "look: a repository with no plugin.json" "$($S look "file://$t/empty.git" me/empty)" "status=noplugin"
expect "look: no such repository" "$($S look "file://$t/nothing.git" me/nothing)" "status="
expect "look: a key that climbs out is refused" "$($S look "$url" ../../etc)" "status=error"

out=$($S install "$url" me/widgets)
expect "install: progress as it goes" "$out" "progress="
expect "install: ok" "$out" "status=ok"
expect "install: the commit" "$out" "commit=$(git -C "$w" rev-parse HEAD)"
expect "install: the plugins in it" "$out" "$(printf '\036weather\037Bar.qml')"
[ -d "$repos/me/widgets/.git" ] && ok "install: cloned into the repos folder" || bad "no clone in the repos folder"
expect "install again: exists" "$($S install "$url" me/widgets)" "status=exists"
expect "install: an empty repository is not kept" "$($S install "file://$t/empty.git" me/empty)" "status=noplugin"
[ ! -e "$repos/me/empty" ] && ok "install: nothing left of it" || bad "an empty repository's clone was left"

expect "link" "$($S link me/widgets clock clock)" "status=ok"
[ "$(readlink -f "$plugins/clock")" = "$repos/me/widgets/clock" ] && ok "link: into the plugins folder" || bad "link went elsewhere"
mkdir -p "$plugins/weather"
expect "link: never over a folder that isn't ours" "$($S link me/widgets weather weather)" "status=exists"
rmdir "$plugins/weather"
expect "link: a bad id is refused" "$($S link me/widgets clock ../x)" "status=error"
expect "link: a path that climbs is refused" "$($S link me/widgets ../../x clock)" "status=error"
$S link me/widgets weather weather >/dev/null

out=$($S check me/widgets)
expect "check: current" "$out" "behind=0"
echo two > "$w/clock/note" && git -C "$w" add -A && git -C "$w" commit -qm "Clock: a second commit" && git -C "$w" push -q "$t/origin.git" main
out=$($S check me/widgets nope/missing)
expect "check: behind" "$out" "behind=1"
expect "check: the commits it brings" "$out" "|Clock: a second commit|"
expect "check: a repository that isn't there" "$out" "$(printf '\036nope/missing\nstatus=missing')"

before=$(git -C "$repos/me/widgets" rev-parse HEAD)
out=$($S update me/widgets)
expect "update: ok" "$out" "status=ok"
expect "update: where it was" "$out" "previous=$before"
expect "update: where it is" "$out" "commit=$(git -C "$w" rev-parse HEAD)"
out=$($S goback me/widgets "$before")
expect "go back: ok" "$out" "status=ok"
[ "$(git -C "$repos/me/widgets" rev-parse HEAD)" = "$before" ] && ok "go back: on the commit before" || bad "go back didn't move"
expect "go back: then it updates again" "$($S update me/widgets)" "status=ok"
expect "go back: a commit that isn't a commit" "$($S goback me/widgets 'x;rm')" "status=error"

expect "needs" "$($S needs sh no-such-program-here)" "$(printf 'sh=yes\nno-such-program-here=no')"
$S lock-save '{"version":1,"repos":{}}' && expect "lock: saved and read" "$($S lock)" '"version":1'
[ ! -e "$t/config/sekaipop/plugins-lock.json.tmp" ] && ok "lock: no temp file left" || bad "lock temp file left"

mkdir -p "$t/state/sekaipop/plugins" && echo '{}' > "$t/state/sekaipop/plugins/clock.json"
$S forget clock && [ ! -e "$t/state/sekaipop/plugins/clock.json" ] && ok "forget: its settings go" || bad "forget left the settings"
$S forget ../x 2>/dev/null; [ $? = 2 ] && ok "forget: a bad id is refused" || bad "forget took a bad id"

touch "$t/keep-me"
out=$($S remove me/widgets)
expect "remove: its plugins unlinked" "$out" "unlinked=clock"
[ ! -e "$plugins/clock" ] && [ ! -e "$plugins/weather" ] && ok "remove: links gone" || bad "remove left a link"
[ ! -e "$repos/me" ] && ok "remove: the clone and its empty owner folder go" || bad "remove left the clone"
[ -e "$t/keep-me" ] && [ -d "$repos" ] && ok "remove: nothing else touched" || bad "remove deleted something else"
expect "remove: a key that climbs is refused" "$($S remove ../..)" "status=error"
[ -e "$t/keep-me" ] && ok "remove: still nothing else touched" || bad "a bad key deleted something"

export SEKAIPOP_PLUGIN_LIST="file://$t/list.json"
echo '[{"repo":"a/b"}]' > "$t/list.json"
expect "fetch-list: from the list's URL" "$($S fetch-list)" "status=ok"
expect "fetch-list: the cached copy" "$(cat "$t/cache/sekaipop/plugins-list.json")" '"a/b"'
rm "$t/list.json"
out=$($S fetch-list)
expect "fetch-list: a failure keeps the last copy" "$(cat "$t/cache/sekaipop/plugins-list.json")" '"a/b"'
expect "fetch-list: and says when it is from" "$out" "at="

[ "$fails" = 0 ] && echo "plugin_repos_test: all checks passed" || { echo "plugin_repos_test: $fails failed"; exit 1; }
