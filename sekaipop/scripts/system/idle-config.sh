#!/bin/sh

# The file side of the idle times (services/IdleService.qml, Settings > General >
# Idle & sleep). hypridle does the waiting; this writes what it waits for.
#
#   idle-config.sh status
#       linked=yes|no|missing   does ~/.config/hypr/hypridle.conf read our file (missing: no
#                               hypridle.conf at all)
#       running=yes|no          is hypridle running
#       hibernate=yes|no|unknown  can this machine hibernate (logind's CanHibernate)
#       file=<path>             our file
#   idle-config.sh write LOCK SCREENOFF SLEEP suspend|hibernate
#       seconds of idle before each, 0 = never. Writes our file only when it changes, and
#       then restarts hypridle if it reads the file. Prints changed=yes|no.
#   idle-config.sh link
#       makes hypridle.conf read our file: its own listener { } blocks are commented out
#       (so two sets of times never race) and a `source =` line is added. A copy of the
#       file as it was is kept once, as hypridle.conf.sekaipop-bak. Restarts hypridle.
#   idle-config.sh restart
#       restart hypridle (it reads its config only when it starts), if it is running
#
# Our file is ${XDG_CONFIG_HOME:-~/.config}/sekaipop/idle.conf. The shipped hypridle.conf
# sources it; one installed before it did (or a hypridle.conf of your own) has its own
# listeners, and `link` is the switch the Settings offer for that.
#
# The lock is `loginctl lock-session`, which hypridle answers with its lock_cmd (the shell's
# lockscreen), so a lock from here goes the same way as one from anywhere else. Sleeping
# locks first through before_sleep_cmd, whether or not the lock time is on.

cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
file="$cfg/sekaipop/idle.conf"
hypr="$cfg/hypr"
idle_cfg="$hypr/hypridle.conf"
MARK='# sekaipop-idle: '

say() { printf '%s\n' "$*" >&2; }

is_link() { [ -L "$1" ]; }

# A `source =` line (not commented out) that names our file.
linked() {
    [ -f "$idle_cfg" ] || { echo missing; return; }
    if grep -qE '^[[:space:]]*source[[:space:]]*=.*sekaipop/idle\.conf' "$idle_cfg"; then
        echo yes
    else
        echo no
    fi
}

running() { pgrep -x hypridle >/dev/null 2>&1; }

can_hibernate() {
    command -v busctl >/dev/null 2>&1 || { echo unknown; return; }
    v=$(busctl --system call org.freedesktop.login1 /org/freedesktop/login1 \
        org.freedesktop.login1.Manager CanHibernate 2>/dev/null | sed -n 's/^s "\(.*\)"$/\1/p')
    case "$v" in
        yes) echo yes ;;
        "") echo unknown ;;
        *) echo no ;;
    esac
}

# Hyprland's Lua config takes its dispatchers as Lua; hyprland.conf takes the old words.
dpms() {
    if [ -f "$hypr/hyprland.lua" ]; then
        if [ "$1" = off ]; then
            echo "hyprctl dispatch 'hl.dsp.dpms({ action = \"disable\" })'"
        else
            echo "hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })'"
        fi
    else
        echo "hyprctl dispatch dpms $1"
    fi
}

render() {
    lock="$1" off="$2" sleep="$3" action="$4"
    echo "# Written by SekaiPop: Settings > General > Idle & sleep (services/IdleService.qml)."
    echo "# Edits here are replaced the next time the times change; set them there, or with"
    echo "#   qs -c sekaipop ipc call options set idle.lock 10      (minutes, 0 = never)"
    echo "# hypridle.conf reads this file with \`source =\`."
    if [ "$lock" -gt 0 ]; then
        printf '\nlistener {\n    timeout = %s\n    on-timeout = loginctl lock-session\n}\n' "$lock"
    fi
    if [ "$off" -gt 0 ]; then
        printf '\nlistener {\n    timeout = %s\n    on-timeout = %s\n    on-resume = %s\n}\n' \
            "$off" "$(dpms off)" "$(dpms on)"
    fi
    if [ "$sleep" -gt 0 ]; then
        if [ "$action" = hibernate ]; then
            cmd='systemctl hibernate || loginctl hibernate'
        else
            cmd='systemctl suspend || loginctl suspend'
        fi
        printf '\nlistener {\n    timeout = %s\n    on-timeout = %s\n}\n' "$sleep" "$cmd"
    fi
}

restart() {
    running || return 0
    # A hypridle started as a user service is restarted by systemd, so it stays one.
    if systemctl --user -q is-active hypridle.service 2>/dev/null; then
        systemctl --user restart hypridle.service
        return
    fi
    pkill -x hypridle 2>/dev/null
    # The old one has to let go of org.freedesktop.ScreenSaver first, or the new one runs
    # without it and apps can no longer hold the screen on (video players, browsers).
    i=0
    while running && [ "$i" -lt 30 ]; do
        sleep 0.1
        i=$((i + 1))
    done
    running && { say "hypridle didn't stop"; return 1; }
    setsid -f hypridle >/dev/null 2>&1 </dev/null
}

is_count() {
    case "$1" in
        '' | *[!0-9]*) return 1 ;;
    esac
}

case "$1" in
    status)
        printf 'linked=%s\n' "$(linked)"
        running && echo running=yes || echo running=no
        printf 'hibernate=%s\n' "$(can_hibernate)"
        printf 'file=%s\n' "$file"
        ;;
    write)
        shift
        for n in "$1" "$2" "$3"; do
            is_count "$n" || { say "usage: $0 write LOCK SCREENOFF SLEEP suspend|hibernate (seconds, 0 = never)"; exit 2; }
        done
        case "$4" in
            suspend | hibernate) ;;
            *) say "the sleep action is suspend or hibernate, not '$4'"; exit 2 ;;
        esac
        new=$(render "$1" "$2" "$3" "$4")
        if [ -f "$file" ] && [ "$(cat "$file")" = "$new" ]; then
            echo changed=no
            exit 0
        fi
        mkdir -p "$(dirname "$file")" || exit 1
        printf '%s\n' "$new" > "$file.tmp" && mv "$file.tmp" "$file" || exit 1
        echo changed=yes
        [ "$(linked)" = yes ] && restart
        exit 0
        ;;
    link)
        [ "$(linked)" = yes ] && { restart; exit 0; }
        if is_link "$idle_cfg"; then
            say "$idle_cfg is a symlink, not editing it: comment out its listener blocks and add"
            say "  source = $file"
            exit 1
        fi
        mkdir -p "$hypr" || exit 1
        if [ -f "$idle_cfg" ]; then
            [ -e "$idle_cfg.sekaipop-bak" ] || cp -p "$idle_cfg" "$idle_cfg.sekaipop-bak" || exit 1
            # Comment out every listener { ... } block, braces counted so a nested { } can't
            # end it early. Everything else (the general block, your own lines) stays.
            awk -v mark="$MARK" '
                function count(s, c,   n, i) { n = 0; for (i = 1; i <= length(s); i++) if (substr(s, i, 1) == c) n++; return n }
                depth == 0 && /^[ \t]*listener[ \t]*\{/ { inblock = 1 }
                inblock {
                    print mark $0
                    depth += count($0, "{") - count($0, "}")
                    if (depth <= 0) { inblock = 0; depth = 0 }
                    next
                }
                { print }
            ' "$idle_cfg" > "$idle_cfg.sekaipop-tmp" || exit 1
        else
            # No hypridle.conf at all: the general block the shipped one has.
            cat > "$idle_cfg.sekaipop-tmp" <<'EOF'
# Idle handling. The lock itself is the shell's lockscreen (ipc call lock lock).
general {
    lock_cmd = qs -c sekaipop ipc call lock lock || pidof hyprlock || hyprlock
    before_sleep_cmd = loginctl lock-session
    after_sleep_cmd = qs -c sekaipop ipc call lock focus
    inhibit_sleep = 3
}
EOF
        fi
        printf '\n# The idle times: Settings > General > Idle & sleep writes them to this file.\nsource = %s\n' \
            "$file" >> "$idle_cfg.sekaipop-tmp" || exit 1
        mv "$idle_cfg.sekaipop-tmp" "$idle_cfg" || exit 1
        restart
        exit 0
        ;;
    restart)
        restart
        ;;
    *)
        say "usage: $0 status | write LOCK SCREENOFF SLEEP suspend|hibernate | link | restart"
        exit 2
        ;;
esac
exit 0
