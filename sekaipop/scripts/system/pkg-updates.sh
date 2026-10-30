#!/bin/sh

# Helper for PackageUpdatesService.qml: how many package updates are waiting.
#
#   pkg-updates.sh check <aur: 1|0>
#
# Prints, one per line:
#   status=ok|nocmd|error        nocmd = no supported package tool was found
#   repo=<n>                     updates from the repositories
#   aur=<n>                      updates from the AUR (paru or yay, if installed and asked for)
#   pkg=<name> <old> -> <new>    the first 40 repository updates
#   aurpkg=<name> <old> -> <new> the first 20 AUR updates
#
# Two backends, tried in this order:
#
#   1. `checkupdates` (Arch, pacman-contrib). It works on a private copy of
#      the sync database: it never needs root and never leaves the system in
#      the "partial upgrade" state that `pacman -Sy` would. Its exit codes are
#      0 (updates), 2 (none) and 1 (error). The AUR (paru or yay) is added on
#      top when asked for.
#
#   2. `apt-get` (Debian and friends). `apt-get -s ... upgrade` is a
#      simulation: it needs no root and changes nothing, but it only reflects
#      whatever `apt update` last fetched (there is no root-free equivalent of
#      refreshing the index itself). Its output has one "Inst <name> [<old>]
#      (<new> ...)" line per upgradable package, which is parsed below. There
#      is no AUR equivalent, so aur is always 0 on this backend.
#
# Neither tool found -> status=nocmd.

mode="$1"
want_aur="${2:-0}"

case "$mode" in
    check)
        if command -v checkupdates >/dev/null 2>&1; then
            out=$(checkupdates 2>/dev/null)
            rc=$?
            case "$rc" in
                0) repo=$(printf '%s\n' "$out" | grep -c .) ;;
                2) repo=0; out="" ;;
                *) echo "status=error"; exit 0 ;;
            esac
            aur=0
            aurout=""
            if [ "$want_aur" = "1" ]; then
                if command -v paru >/dev/null 2>&1; then
                    aurout=$(paru -Qua 2>/dev/null)
                elif command -v yay >/dev/null 2>&1; then
                    aurout=$(yay -Qua 2>/dev/null)
                fi
                [ -n "$aurout" ] && aur=$(printf '%s\n' "$aurout" | grep -c .)
            fi
            echo "status=ok"
            echo "repo=$repo"
            echo "aur=$aur"
            [ -n "$out" ] && printf '%s\n' "$out" | head -n 40 | awk 'NF >= 4 { print "pkg=" $1 " " $2 " -> " $4 }'
            [ -n "$aurout" ] && printf '%s\n' "$aurout" | head -n 20 | awk 'NF >= 4 { print "aurpkg=" $1 " " $2 " -> " $4 }'
            exit 0
        elif command -v apt-get >/dev/null 2>&1; then
            out=$(apt-get -s -o Debug::NoLocking=1 -o APT::Get::Show-User-Simulation-Note=0 upgrade 2>/dev/null)
            rc=$?
            if [ "$rc" != 0 ]; then
                echo "status=error"
                exit 0
            fi
            # Lines look like: Inst foo [1.0-1] (1.1-1 Debian:13/stable [amd64])
            insts=$(printf '%s\n' "$out" | grep '^Inst ')
            repo=$(printf '%s\n' "$insts" | grep -c .)
            [ -n "$insts" ] || repo=0
            echo "status=ok"
            echo "repo=$repo"
            echo "aur=0"
            [ -n "$insts" ] && printf '%s\n' "$insts" | head -n 40 | sed -n \
                's/^Inst \([^ ]*\) \[\([^]]*\)\] (\([^ ]*\).*/pkg=\1 \2 -> \3/p'
            exit 0
        else
            echo "status=nocmd"
            exit 0
        fi
        ;;
    *)
        echo "usage: $0 check <aur 1|0>" >&2
        exit 2
        ;;
esac
