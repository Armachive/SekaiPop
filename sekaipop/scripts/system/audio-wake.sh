#!/bin/sh
# Wakes a sound card that WirePlumber probed too early.
#
# On some laptops (Intel SOF audio, Debian 13 seen here) WirePlumber starts at boot a moment
# before the DSP firmware has finished loading. It then finds the card but no usable profile,
# leaves it on "Off", and the session has only a "Dummy Output": no speakers, no mic, even
# though `aplay -l` lists the card. A restart of WirePlumber re-probes it and the normal
# "HiFi" profile comes back. This does that once, only when the symptom is there.
#
# Run by Hyprland at session start (hyprland/execs.lua), a few seconds in, so the card has had
# its time. Harmless when everything is fine: it prints one line and exits.
#
#   audio-wake.sh            check, and restart WirePlumber if every card is Off
#   audio-wake.sh status     only say what it sees

command -v pactl >/dev/null 2>&1 || { echo "audio-wake: pactl not installed"; exit 0; }
sleep "${SEKAIPOP_AUDIO_WAKE_DELAY:-6}"

cards=$(pactl list cards 2>/dev/null)
n=$(printf '%s\n' "$cards" | grep -c '^Card #')
active=$(printf '%s\n' "$cards" | grep -c 'Active Profile: off')
sinks=$(pactl list short sinks 2>/dev/null | grep -vc 'auto_null')

echo "audio-wake: $n card(s), $active on profile Off, $sinks real sink(s)"
[ "$1" = status ] && exit 0
[ "$n" -gt 0 ] && [ "$sinks" -eq 0 ] && [ "$active" -ge 1 ] || exit 0

echo "audio-wake: no usable output, re-probing the sound card (restarting wireplumber)"
systemctl --user restart wireplumber 2>/dev/null || exit 0
sleep 3
pactl list short sinks 2>/dev/null | grep -vc 'auto_null' | sed 's/^/audio-wake: sinks now: /'
