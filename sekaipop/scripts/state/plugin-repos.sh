#!/bin/sh

# Helper for PluginRepoService.qml: gets plugin repositories, updates them, and keeps the
# lockfile (docs/PLUGIN-INSTALL.md). Everything that touches git or the network is here; what
# it prints is read by modules/common/functions/PluginRepos.js.
#
#   plugin-repos.sh paths                     print repos= plugins= lock= list= (the folders)
#   plugin-repos.sh fetch-list                fetch the reviewed list into the cache; print
#                                             status=ok|offline|error, at= (the cache's time)
#   plugin-repos.sh look <url> <key>          shallow-clone to a scratch folder, print the plugin
#                                             folders in it (the scan's records), delete it
#   plugin-repos.sh install <url> <key>       clone into the repos folder, printing git's progress
#                                             as it goes; then status=, commit= and the records
#   plugin-repos.sh link <key> <path> <id>    link a plugin folder of a repository into the plugins
#                                             folder (status=ok|exists)
#   plugin-repos.sh check <key>...            fetch each and say how far behind it is (records)
#   plugin-repos.sh update <key>              fast-forward to upstream; print previous= commit=
#   plugin-repos.sh goback <key> <commit>     move back to a commit; print previous= commit=
#   plugin-repos.sh remove <key>              unlink its plugins and delete its clone
#   plugin-repos.sh forget <id>               delete a plugin's saved state (its settings)
#   plugin-repos.sh needs <program>...        print <program>=yes|no for each
#   plugin-repos.sh lock                      print the lockfile (or nothing)
#   plugin-repos.sh lock-save <json>          replace the lockfile, through a temp file
#
# A key is "owner/repo" (GitHub) or "host/path": it names a folder under the repos folder, so
# it is checked before it is used, and nothing is ever deleted outside that folder. Never asks
# for a password: a private or missing repository fails instead of hanging the shell.

mode="$1"
shift 2>/dev/null

config="${XDG_CONFIG_HOME:-$HOME/.config}/sekaipop"
data="${XDG_DATA_HOME:-$HOME/.local/share}/sekaipop"
cache="${XDG_CACHE_HOME:-$HOME/.cache}/sekaipop"
state="${XDG_STATE_HOME:-$HOME/.local/state}/sekaipop/plugins"
repos="$data/plugin-repos"
plugins="${SEKAIPOP_PLUGINS_DIR:-$config/plugins}"
lockfile="$config/plugins-lock.json"
listcache="$cache/plugins-list.json"
# The reviewed list: plugins.json at the root of the SekaiPop repository. A fork, or a test,
# can point elsewhere (a URL, or a file:// path).
listurl="${SEKAIPOP_PLUGIN_LIST:-https://raw.githubusercontent.com/Blapples/SekaiPop/main/plugins.json}"

export GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true SSH_ASKPASS=/bin/true
export GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=15"

valid_key() {
    case "$1" in
        ''|/*|*/|*..*|*//*) return 1 ;;
        */*) ;;
        *) return 1 ;;
    esac
    case "$1" in
        *[!A-Za-z0-9._/-]*) return 1 ;;
    esac
    return 0
}

valid_id() {
    case "$1" in
        ''|*[!a-z0-9-]*|-*) return 1 ;;
    esac
    return 0
}

# Why a clone or fetch failed, from what git said.
reason_of() {
    if grep -qiE "could not resolve host|network is unreachable|connection timed out|failed to connect|temporary failure" "$1"; then
        echo offline
    elif grep -qiE "not found|could not read username|authentication failed|permission denied|does not exist|repository .* not" "$1"; then
        echo norepo
    else
        tail -n 1 "$1" | sed 's/^fatal: //'
    fi
}

# The plugin folders of a cloned repository, as the plugins scan prints them:
# "\036<path>\037<its QML files>" then its plugin.json. <path> is "" for the root.
records() {
    root="$1"
    find "$root" -maxdepth 3 -name plugin.json -not -path '*/.git/*' 2>/dev/null | sort | while read -r f; do
        d=$(dirname "$f")
        rel=${d#"$root"}
        rel=${rel#/}
        files=""
        for q in Widget.qml Bar.qml Popup.qml Service.qml; do
            [ -f "$d/$q" ] && files="${files:+$files }$q"
        done
        printf '\036%s\037%s\n' "$rel" "$files"
        cat "$f"
        printf '\n'
    done
}

case "$mode" in
    paths)
        printf 'repos=%s\nplugins=%s\nlock=%s\nlist=%s\n' "$repos" "$plugins" "$lockfile" "$listcache"
        ;;

    fetch-list)
        mkdir -p "$cache" || exit 1
        tmp="$listcache.tmp"
        err="$cache/plugins-list.err"
        if curl -fsSL --max-time 20 "$listurl" -o "$tmp" 2>"$err"; then
            mv "$tmp" "$listcache"
            echo "status=ok"
        else
            rm -f "$tmp"
            if grep -qiE "resolve host|connect|timed out|network" "$err"; then
                echo "status=offline"
            else
                echo "status=error"
                echo "reason=$(tail -n 1 "$err" | sed 's/^curl: ([0-9]*) //')"
            fi
        fi
        rm -f "$err"
        [ -f "$listcache" ] && echo "at=$(date -r "$listcache" +%s)"
        exit 0
        ;;

    look)
        url="$1"; key="$2"
        valid_key "$key" || { echo "status=error"; echo "reason=not a repository"; exit 0; }
        command -v git >/dev/null 2>&1 || { echo "status=nogit"; exit 0; }
        mkdir -p "$cache" || exit 1
        tmp=$(mktemp -d "$cache/look.XXXXXX") || exit 1
        log="$tmp.log"
        if git clone --depth 1 --quiet "$url" "$tmp/repo" >"$log" 2>&1; then
            out=$(records "$tmp/repo")
            if [ -z "$out" ]; then
                echo "status=noplugin"
            else
                echo "status=ok"
                printf '%s\n' "$out"
            fi
        else
            echo "status=$(reason_of "$log")"
        fi
        rm -rf "$tmp" "$log"
        exit 0
        ;;

    install)
        url="$1"; key="$2"
        valid_key "$key" || { echo "status=error"; echo "reason=not a repository"; exit 0; }
        command -v git >/dev/null 2>&1 || { echo "status=nogit"; exit 0; }
        dest="$repos/$key"
        if [ -e "$dest" ]; then
            echo "status=exists"
            exit 0
        fi
        mkdir -p "$(dirname "$dest")" "$cache" || exit 1
        log=$(mktemp "$cache/install.XXXXXX") || exit 1
        # git's progress goes to stderr with carriage returns; one line per step, as it comes,
        # so the screen's meter moves (PluginRepos.cloneProgress reads them).
        { git clone --progress "$url" "$dest" 2>&1; echo "__rc=$?"; } | tr '\r' '\n' | tee "$log" | grep --line-buffered -E '^(Counting|Compressing|Receiving|Resolving)' | sed -u 's/^/progress=/'
        rc=$(sed -n 's/^__rc=//p' "$log" | tail -n 1)
        if [ "$rc" != 0 ]; then
            echo "status=$(reason_of "$log")"
            rm -rf "$dest" "$log"
            exit 0
        fi
        rm -f "$log"
        out=$(records "$dest")
        if [ -z "$out" ]; then
            rm -rf "$dest"
            echo "status=noplugin"
            exit 0
        fi
        echo "status=ok"
        echo "commit=$(git -C "$dest" rev-parse HEAD)"
        printf '%s\n' "$out"
        ;;

    link)
        key="$1"; path="$2"; id="$3"
        valid_key "$key" && valid_id "$id" || { echo "status=error"; exit 0; }
        case "$path" in *..*|/*) echo "status=error"; exit 0 ;; esac
        src="$repos/$key${path:+/$path}"
        dest="$plugins/$id"
        [ -f "$src/plugin.json" ] || { echo "status=error"; exit 0; }
        mkdir -p "$plugins" || exit 1
        # Only a link that is already one of ours (into the repos folder) may be replaced.
        if [ -e "$dest" ] || [ -L "$dest" ]; then
            case "$(readlink -f "$dest" 2>/dev/null)" in
                "$repos"/*) ;;
                *) echo "status=exists"; exit 0 ;;
            esac
        fi
        ln -sfn "$src" "$dest" && echo "status=ok"
        ;;

    check)
        for key in "$@"; do
            valid_key "$key" || continue
            dir="$repos/$key"
            printf '\036%s\n' "$key"
            if [ ! -d "$dir/.git" ]; then
                echo "status=missing"
                continue
            fi
            mkdir -p "$cache"; err=$(mktemp "$cache/fetch.XXXXXX")
            if ! timeout 60 git -C "$dir" fetch --quiet 2>"$err"; then
                echo "status=$(reason_of "$err")"
                rm -f "$err"
                continue
            fi
            rm -f "$err"
            if ! git -C "$dir" rev-parse --verify --quiet '@{u}' >/dev/null; then
                echo "status=noupstream"
                continue
            fi
            echo "status=ok"
            echo "head=$(git -C "$dir" rev-parse --short HEAD)"
            echo "upstream=$(git -C "$dir" rev-parse --short '@{u}')"
            echo "behind=$(git -C "$dir" rev-list --count 'HEAD..@{u}')"
            git -C "$dir" log --format='log=%h|%s|%cr' -n 20 'HEAD..@{u}'
        done
        ;;

    update)
        key="$1"
        valid_key "$key" && [ -d "$repos/$key/.git" ] || { echo "status=missing"; exit 0; }
        dir="$repos/$key"
        echo "previous=$(git -C "$dir" rev-parse HEAD)"
        if git -C "$dir" merge --ff-only --quiet '@{u}' 2>/dev/null; then
            echo "status=ok"
        else
            echo "status=error"
            echo "reason=it can't move forward from where it is (local changes in its folder?)"
        fi
        echo "commit=$(git -C "$dir" rev-parse HEAD)"
        ;;

    goback)
        key="$1"; commit="$2"
        valid_key "$key" && [ -d "$repos/$key/.git" ] || { echo "status=missing"; exit 0; }
        case "$commit" in ''|*[!0-9a-f]*) echo "status=error"; exit 0 ;; esac
        dir="$repos/$key"
        echo "previous=$(git -C "$dir" rev-parse HEAD)"
        # reset, not checkout: the branch stays, so a later update fast-forwards again.
        if git -C "$dir" reset --hard --quiet "$commit" 2>/dev/null; then
            echo "status=ok"
        else
            echo "status=error"
            echo "reason=that commit isn't in its history"
        fi
        echo "commit=$(git -C "$dir" rev-parse HEAD)"
        ;;

    remove)
        key="$1"
        valid_key "$key" || { echo "status=error"; exit 0; }
        dir="$repos/$key"
        for l in "$plugins"/*; do
            [ -L "$l" ] || continue
            case "$(readlink -f "$l" 2>/dev/null)" in
                "$dir"|"$dir"/*) rm -f "$l"; echo "unlinked=$(basename "$l")" ;;
            esac
        done
        # Still inside the repos folder, as valid_key promised; then drop empty owner folders.
        case "$(readlink -f "$dir" 2>/dev/null)" in
            "$repos"/*) rm -rf "$dir" ;;
        esac
        rmdir "$(dirname "$dir")" 2>/dev/null
        echo "status=ok"
        ;;

    forget)
        valid_id "$1" || exit 2
        rm -f "$state/$1.json"
        ;;

    needs)
        for p in "$@"; do
            case "$p" in *[!A-Za-z0-9._+-]*) continue ;; esac
            if command -v "$p" >/dev/null 2>&1; then echo "$p=yes"; else echo "$p=no"; fi
        done
        ;;

    lock)
        [ -f "$lockfile" ] && cat "$lockfile"
        exit 0
        ;;

    lock-save)
        mkdir -p "$config" || exit 1
        printf '%s\n' "$1" > "$lockfile.tmp" || exit 1
        mv "$lockfile.tmp" "$lockfile"
        ;;

    *)
        echo "usage: $0 paths|fetch-list|look|install|link|check|update|goback|remove|forget|needs|lock|lock-save" >&2
        exit 2
        ;;
esac
