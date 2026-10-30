#!/usr/bin/env bash
# Compiles every .vert/.frag GLSL source in this directory into the
# .qsb (Qt Shader Bytecode) files WallpaperLayer.qml actually loads at
# runtime — it never reads a .vert/.frag directly, only the .qsb next
# to it. Re-run this any time a shader source here changes.
#
# Needs Qt6's `qsb` (ships in qt6-shadertools on Arch: `pacman -S
# qt6-shadertools`; on Debian it's the qt6-shader-baker package: `sudo
# apt install qt6-shader-baker`). Neither package symlinks it onto
# PATH — it only installs to /usr/lib/qt6/bin/qsb (or, on Debian's
# multiarch layout, /usr/lib/x86_64-linux-gnu/qt6/bin/qsb) — so this
# script checks those paths itself rather than requiring you to add
# them to PATH by hand.
#
# Has a bash shebang so it runs the same regardless of your login
# shell — safe to invoke from fish as `./shaders/compile-shaders.sh`.
set -euo pipefail
cd "$(dirname "$0")"

QSB=qsb
if ! command -v "$QSB" >/dev/null 2>&1; then
    for candidate in /usr/lib/qt6/bin/qsb /usr/lib/x86_64-linux-gnu/qt6/bin/qsb /usr/lib/qt6-shadertools/bin/qsb; do
        if [ -x "$candidate" ]; then
            QSB="$candidate"
            break
        fi
    done
fi

if ! command -v "$QSB" >/dev/null 2>&1 && [ ! -x "$QSB" ]; then
    echo "error: qsb not found on PATH or in /usr/lib/qt6/bin." >&2
    echo "  Arch: pacman -S qt6-shadertools" >&2
    echo "  Debian: sudo apt install qt6-shader-baker" >&2
    echo "  (those install qsb to /usr/lib/qt6/bin (or, on Debian's" >&2
    echo "  multiarch layout, /usr/lib/x86_64-linux-gnu/qt6/bin), which" >&2
    echo "  this script checks automatically — if it's still not found," >&2
    echo "  your Qt6 install may put it somewhere else; find it with:" >&2
    echo "  sudo find / -name qsb -type f 2>/dev/null)" >&2
    exit 1
fi

shopt -s nullglob
sources=(*.vert *.frag)
shopt -u nullglob

if [ ${#sources[@]} -eq 0 ]; then
    echo "no .vert/.frag sources found in $(pwd)"
    exit 0
fi

for src in "${sources[@]}"; do
    out="${src}.qsb"
    echo "compiling ${src} -> ${out}"
    # --qt6 picks sane default target versions for every RHI backend
    # (GL/Vulkan/Metal/D3D) on newer qsb. Older qsb (pre-6.5-ish, e.g.
    # the 6.4 shipped by Ubuntu 24.04's qt6-shader-baker) doesn't know
    # that flag at all and exits 1 with "Unknown option 'qt6'" before
    # writing anything — silently leaving every WallpaperLayer.qml
    # ShaderEffect with no .qsb to load. Try --qt6 first; if that's
    # the specific failure, fall back to the explicit target list.
    err=$("$QSB" --qt6 -o "$out" "$src" 2>&1) && continue
    if printf '%s' "$err" | grep -q "Unknown option 'qt6'"; then
        "$QSB" --glsl "100 es,120,150" --hlsl 50 --msl 12 -o "$out" "$src"
    else
        printf '%s\n' "$err" >&2
        exit 1
    fi
done

echo "done."
