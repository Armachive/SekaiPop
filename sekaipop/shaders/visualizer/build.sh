#!/bin/sh
cd "$(dirname "$0")" || exit 1
QSB=$(command -v qsb || command -v qsb6 || ls /usr/lib/qt6/bin/qsb /usr/lib/x86_64-linux-gnu/qt6/bin/qsb /usr/lib64/qt6/bin/qsb 2>/dev/null | head -n 1)
if [ -z "$QSB" ]; then
    echo "qsb not found: install qt6-shadertools (Arch: pacman -S qt6-shadertools) / qt6-shader-baker (Debian: sudo apt install qt6-shader-baker) / qt6-qtshadertools (Fedora)" >&2
    exit 1
fi
status=0
for f in tide ribbons scope pulse; do
    [ -f "$f.frag" ] || continue
    # Same targets as the other visualizer shaders. Keep these sources free of int
    # min/max/clamp: GLSL ES 1.00 has no int overloads, and NVIDIA's GLES driver (which Qt
    # uses through the "100 es" variant) refuses them, leaving the visualizer blank.
    if "$QSB" --glsl "100 es,120,150,300 es" --hlsl 50 --msl 12 -o "$f.frag.qsb" "$f.frag"; then
        echo "wrote $f.frag.qsb"
    else
        echo "FAILED: $f.frag" >&2
        status=1
    fi
done
exit $status
