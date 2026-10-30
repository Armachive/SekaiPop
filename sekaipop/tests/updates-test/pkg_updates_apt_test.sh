#!/bin/sh
# Runs scripts/system/pkg-updates.sh against a fake apt-get (no checkupdates
# on PATH, as on Debian), with an `-s upgrade` transcript to parse, an empty
# one, and then neither tool installed.
#   sh tests/updates-test/pkg_updates_apt_test.sh
here=$(cd "$(dirname "$0")/../.." && pwd)
t=$(mktemp -d) && trap 'rm -rf "$t"' EXIT
fail=0
ok()  { printf '  ok   %s\n' "$1"; }
bad() { printf '  FAIL %s\n' "$1"; fail=1; }
expect() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (wanted '$3', got: $(echo "$2" | tr '\n' ' '))" ;; esac; }

S="sh $here/scripts/system/pkg-updates.sh"

# --- a realistic `apt-get -s upgrade` transcript, 3 upgrades -----------------
mkdir -p "$t/bin"
cat > "$t/bin/apt-get" <<'EOF'
#!/bin/sh
cat <<'OUT'
Reading package lists...
Building dependency tree...
Reading state information...
The following packages will be upgraded:
  firefox libfoo1 vim
3 upgraded, 0 newly installed, 0 to remove and 0 not upgraded.
Inst libfoo1 [1.2-1] (1.3-1 Debian:13/stable [amd64])
Inst vim [2:8.2.0-1] (2:8.2.1-1 Debian:13/stable [amd64])
Inst firefox [120.0-1] (121.0-1 Debian:13/stable [amd64])
Conf libfoo1 (1.3-1 Debian:13/stable [amd64])
Conf vim (2:8.2.1-1 Debian:13/stable [amd64])
Conf firefox (121.0-1 Debian:13/stable [amd64])
OUT
EOF
chmod +x "$t/bin/apt-get"

out=$(PATH="$t/bin:$PATH" $S check 0)
expect "apt: status=ok" "$out" "status=ok"
expect "apt: repo count" "$out" "repo=3"
expect "apt: aur is always 0" "$out" "aur=0"
expect "apt: pkg line (libfoo1)" "$out" "pkg=libfoo1 1.2-1 -> 1.3-1"
expect "apt: pkg line (vim, epoch kept)" "$out" "pkg=vim 2:8.2.0-1 -> 2:8.2.1-1"
expect "apt: pkg line (firefox)" "$out" "pkg=firefox 120.0-1 -> 121.0-1"

# --- an empty transcript: nothing to upgrade ---------------------------------
cat > "$t/bin/apt-get" <<'EOF'
#!/bin/sh
cat <<'OUT'
Reading package lists...
Building dependency tree...
Reading state information...
0 upgraded, 0 newly installed, 0 to remove and 0 not upgraded.
OUT
EOF
chmod +x "$t/bin/apt-get"

out=$(PATH="$t/bin:$PATH" $S check 0)
expect "apt, nothing to upgrade: status=ok" "$out" "status=ok"
expect "apt, nothing to upgrade: repo=0" "$out" "repo=0"

# --- neither checkupdates nor apt-get on PATH --------------------------------
mkdir -p "$t/empty"
ln -s "$(command -v sh)" "$t/empty/sh"
out=$(PATH="$t/empty" $S check 0)
expect "neither tool: status=nocmd" "$out" "status=nocmd"

[ $fail = 0 ] && echo "all passed" || { echo "FAILED"; exit 1; }
