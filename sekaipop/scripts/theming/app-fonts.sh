#!/bin/sh

# Helper for AppFontService.qml: the font GTK, Qt and KDE apps use, changed while they run.
#
#   app-fonts.sh list ui|mono          installed font families, one per line (mono: the ones
#                                      fontconfig calls monospaced, dual-width or char-cell)
#   app-fonts.sh get                   ui=<family> uisize=<pt> mono=<family> monosize=<pt>
#                                      (what GTK reads; an empty value is "not set")
#   app-fonts.sh set ui|mono <family> <size>
#   app-fonts.sh check                 where each kind of app reads its font, and what is
#                                      there now, for debugging
#
# WHERE APPS READ THEIR FONT (issue #98: a font set in only one of these seems to "reset")
#   GTK 3 / 4  GNOME's font-name / monospace-font-name (dconf, else gsettings). On Wayland
#              this wins over gtk-font-name in ~/.config/gtk-3.0/settings.ini, which only
#              apps that never ask GNOME's settings read; both are written. document-font-name
#              (reading views in some GNOME apps) follows the UI font.
#   Qt, KDE    with QT_QPA_PLATFORMTHEME=kde (what SekaiPop's Hyprland config sets), Qt apps
#              read ~/.config/kdeglobals: [General] font, menuFont, toolBarFont,
#              smallestReadableFont (two points smaller), fixed, and [WM] activeFont. Fonts set
#              in qt6ct are not read at all then.
#   qt5ct /    with QT_QPA_PLATFORMTHEME=qt5ct / qt6ct, [Fonts] general / fixed in
#   qt6ct      qt5ct.conf / qt6ct.conf (only when that file exists or the tool is installed).
# Only the keys named here are written; everything else in those files stays (a file that
# is a symlink is left alone, and you are told the key to set).
#
# LIVE
#   GTK apps follow GNOME's settings at once. KDE's platform theme reloads its fonts on the
#   org.kde.KDEPlatformTheme.refreshFonts signal (plasma-integration, kfontsettingsdata.cpp),
#   and KDE Frameworks 5 apps on KGlobalSettings.notifyChange(FontChanged); both are sent.
#   qt5ct / qt6ct watch their own config folder.
#
# Exit codes: 0 done, 2 bad arguments or no such font.

mode_cmd="$1"
[ $# -gt 0 ] && shift

cfgdir="${XDG_CONFIG_HOME:-$HOME/.config}"
kdeglobals="$cfgdir/kdeglobals"

say() { printf 'app-fonts: %s\n' "$*" >&2; }

is_link() { [ -L "$1" ]; }

# ini_set FILE SECTION KEY VALUE: sets KEY=VALUE inside [SECTION], adding the key or the
# whole section (or the file) if it isn't there. Everything else is copied as it was.
# (Same helper as in system-theme.sh and icon-cursor.sh.)
ini_set() {
    f="$1"
    if is_link "$f"; then say "$f is a symlink, not editing it (set $3=$4 under [$2] yourself)"; return 0; fi
    mkdir -p "$(dirname "$f")" || return 1
    [ -f "$f" ] || : > "$f"
    SEC="$2" KEY="$3" VAL="$4" awk '
        function put_key() { print ENVIRON["KEY"] "=" ENVIRON["VAL"]; done = 1 }
        function release() { for (; held > 0; held--) print ""; }
        function close_section() { if (insec && !done) put_key(); release() }
        /^\[.*\][ \t]*$/ {
            close_section()
            insec = ($0 == "[" ENVIRON["SEC"] "]")
            if (insec) seen = 1
            print
            next
        }
        insec && /^[ \t]*$/ { held++; next }
        insec && index($0, ENVIRON["KEY"] "=") == 1 {
            release()
            if (!done) put_key()
            next
        }
        { release(); print }
        END {
            if (!seen) {
                if (NR > 0) print ""
                print "[" ENVIRON["SEC"] "]"
                print ENVIRON["KEY"] "=" ENVIRON["VAL"]
            } else close_section()
        }
    ' "$f" > "$f.sekaipop-tmp" && mv "$f.sekaipop-tmp" "$f"
}

# ===== GNOME interface settings (dconf first, like icon-cursor.sh) =====
iface_get() {
    v=""
    if command -v dconf >/dev/null 2>&1; then
        v="$(dconf read "/org/gnome/desktop/interface/$1" 2>/dev/null | sed "s/^'//;s/'\$//")"
    fi
    if [ -z "$v" ] && command -v gsettings >/dev/null 2>&1; then
        v="$(gsettings get org.gnome.desktop.interface "$1" 2>/dev/null | sed "s/^'//;s/'\$//")"
    fi
    if [ -z "$v" ] && [ "$1" = font-name ] && [ -f "$cfgdir/gtk-3.0/settings.ini" ]; then
        v="$(sed -n 's/^gtk-font-name=//p' "$cfgdir/gtk-3.0/settings.ini" | head -n 1)"
    fi
    printf '%s' "$v"
}
iface_set() {
    if command -v dconf >/dev/null 2>&1; then
        dconf write "/org/gnome/desktop/interface/$1" "'$2'" 2>/dev/null && return 0
    fi
    command -v gsettings >/dev/null 2>&1 && gsettings set org.gnome.desktop.interface "$1" "$2" 2>/dev/null
}

# "Noto Sans 10" -> family / size (a Pango description: the size is the last word).
desc_family() { printf '%s' "$1" | sed -E 's/[[:space:]]+[0-9]+([.][0-9]+)?$//'; }
desc_size() { printf '%s' "$1" | sed -nE 's/.*[[:space:]]([0-9]+)([.][0-9]+)?$/\1/p'; }

# ===== which fonts exist =====
list_fonts() {
    command -v fc-list >/dev/null 2>&1 || { say "fc-list (fontconfig) is not installed"; return 1; }
    case "$1" in
        mono)
            for s in 90 100 110; do
                fc-list ":spacing=$s" --format '%{family[0]}\n'
            done ;;
        *)
            fc-list --format '%{family[0]}\n' ;;
    esac | sed '/^$/d' | sort -u
}

# The name goes into a dconf string, a KDE font string (comma separated) and a quoted
# QSettings value, so none of their separators may be in it.
valid_family() {
    case "$1" in
        '' | ' '* | *' ' | *[,\"\'\\=]* ) return 1 ;;
    esac
    [ "$(printf '%s' "$1" | wc -l)" -eq 0 ]
}

need_font() {
    if ! valid_family "$1"; then say "not a usable font name: $1"; exit 2; fi
    if ! list_fonts ui | grep -Fxq -- "$1"; then say "no font called $1 is installed"; exit 2; fi
}

need_size() {
    case "$1" in
        ''|*[!0-9]*) say "not a size: $1"; exit 2 ;;
    esac
    if [ "$1" -lt 6 ] || [ "$1" -gt 72 ]; then say "size out of range (6-72): $1"; exit 2; fi
}

# QFont::toString() as Qt 6 writes it (what Plasma 6 and qt6ct store), and as Qt 5 does (qt5ct).
qt6_font() { printf '%s,%s,-1,5,400,0,0,0,0,0,0,0,0,0,0,1' "$1" "$2"; }
qt5_font() { printf '%s,%s,-1,5,50,0,0,0,0,0' "$1" "$2"; }

# ===== KDE =====
# Qt apps read kdeglobals whenever the KDE platform theme is in use, KDE installed or not.
kde_wanted() {
    [ "${QT_QPA_PLATFORMTHEME:-}" = kde ] || [ -f "$kdeglobals" ] \
        || command -v dolphin >/dev/null 2>&1 \
        || command -v kwriteconfig6 >/dev/null 2>&1 \
        || command -v plasma-apply-colorscheme >/dev/null 2>&1
}

# kde_emit PATH IFACE.SIGNAL [INT...]: a signal on the session bus.
kde_emit() {
    p="$1"; sig="$2"; shift 2
    if command -v dbus-send >/dev/null 2>&1; then
        args=""
        for a in "$@"; do args="$args int32:$a"; done
        # shellcheck disable=SC2086
        dbus-send --session --type=signal "$p" "$sig" $args >/dev/null 2>&1
    elif command -v gdbus >/dev/null 2>&1; then
        gdbus emit --session --object-path "$p" --signal "$sig" "$@" >/dev/null 2>&1
    fi
}

qtct_each() {
    for q in 5 6; do
        f="$cfgdir/qt${q}ct/qt${q}ct.conf"
        if [ -f "$f" ] || command -v "qt${q}ct" >/dev/null 2>&1; then
            printf '%s %s\n' "$q" "$f"
        fi
    done
}

# ===== set =====
apply_ui() {
    fam="$1"; size="$2"
    small=$((size - 2)); [ "$small" -lt 6 ] && small=6

    for v in 3.0 4.0; do
        ini_set "$cfgdir/gtk-$v/settings.ini" Settings gtk-font-name "$fam $size"
    done

    qtct_each | while read -r q f; do
        if [ "$q" = 5 ]; then val="$(qt5_font "$fam" "$size")"; else val="$(qt6_font "$fam" "$size")"; fi
        ini_set "$f" Fonts general "\"$val\""
    done

    if kde_wanted; then
        for k in font menuFont toolBarFont; do
            ini_set "$kdeglobals" General "$k" "$(qt6_font "$fam" "$size")"
        done
        ini_set "$kdeglobals" General smallestReadableFont "$(qt6_font "$fam" "$small")"
        ini_set "$kdeglobals" WM activeFont "$(qt6_font "$fam" "$size")"
    fi

    # Last, so everything GTK might read is already in place when it hears about it.
    iface_set font-name "$fam $size" || say "could not set GNOME's font-name (neither dconf nor gsettings worked)"
    iface_set document-font-name "$fam $size"
}

apply_mono() {
    fam="$1"; size="$2"

    qtct_each | while read -r q f; do
        if [ "$q" = 5 ]; then val="$(qt5_font "$fam" "$size")"; else val="$(qt6_font "$fam" "$size")"; fi
        ini_set "$f" Fonts fixed "\"$val\""
    done

    kde_wanted && ini_set "$kdeglobals" General fixed "$(qt6_font "$fam" "$size")"

    iface_set monospace-font-name "$fam $size" || say "could not set GNOME's monospace-font-name (neither dconf nor gsettings worked)"
}

refresh_kde() {
    kde_wanted || return 0
    kde_emit /KDEPlatformTheme org.kde.KDEPlatformTheme.refreshFonts
    # KGlobalSettings::ChangeType 1 = FontChanged
    kde_emit /KGlobalSettings org.kde.KGlobalSettings.notifyChange 1 0
}

# ===== check =====
do_check() {
    for t in fc-list dconf gsettings dbus-send gdbus qt5ct qt6ct; do
        echo "$t: $(command -v "$t" || echo 'not found')"
    done
    echo "QT_QPA_PLATFORMTHEME in this shell: '${QT_QPA_PLATFORMTHEME:-}'"
    case "${QT_QPA_PLATFORMTHEME:-}" in
        kde) echo "  kde: Qt apps read their fonts from kdeglobals [General] (qt6ct's [Fonts] is not read)" ;;
        qt5ct|qt6ct) echo "  $QT_QPA_PLATFORMTHEME: Qt apps read [Fonts] in $QT_QPA_PLATFORMTHEME.conf" ;;
        *) echo "  not kde / qt5ct / qt6ct: Qt apps use Qt's default font" ;;
    esac
    echo "GTK (GNOME font-name):           '$(iface_get font-name)'"
    echo "GTK (GNOME monospace-font-name): '$(iface_get monospace-font-name)'"
    for v in 3.0 4.0; do
        echo "gtk-$v/settings.ini gtk-font-name: '$(sed -n 's/^gtk-font-name=//p' "$cfgdir/gtk-$v/settings.ini" 2>/dev/null | head -n 1)'"
    done
    echo "kdeglobals font:  '$(sed -n 's/^font=//p' "$kdeglobals" 2>/dev/null | head -n 1)'"
    echo "kdeglobals fixed: '$(sed -n 's/^fixed=//p' "$kdeglobals" 2>/dev/null | head -n 1)'"
    qtct_each | while read -r q f; do
        echo "qt${q}ct general: '$(sed -n 's/^general=//p' "$f" 2>/dev/null | head -n 1)'  fixed: '$(sed -n 's/^fixed=//p' "$f" 2>/dev/null | head -n 1)'"
    done
    echo "font families found: $(list_fonts ui | wc -l) ($(list_fonts mono | wc -l) monospaced)"
}

case "$mode_cmd" in
    list)
        case "$1" in
            ui|mono) list_fonts "$1" ;;
            *) say "usage: list ui|mono"; exit 2 ;;
        esac ;;
    get)
        ui="$(iface_get font-name)"
        mono="$(iface_get monospace-font-name)"
        echo "ui=$(desc_family "$ui")"
        echo "uisize=$(desc_size "$ui")"
        echo "mono=$(desc_family "$mono")"
        echo "monosize=$(desc_size "$mono")" ;;
    set)
        kind="$1"
        case "$kind" in
            ui|mono) ;;
            *) say "usage: set ui|mono <family> <size>"; exit 2 ;;
        esac
        need_font "$2"
        need_size "$3"
        if [ "$kind" = ui ]; then apply_ui "$2" "$3"; else apply_mono "$2" "$3"; fi
        refresh_kde ;;
    check)
        do_check ;;
    *)
        say "usage: app-fonts.sh list ui|mono | get | set ui|mono <family> <size> | check"
        exit 2 ;;
esac
exit 0
