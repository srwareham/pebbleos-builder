#!/usr/bin/env bash
# Launch the PebbleOS QEMU emulator inside Docker with Wayland display forwarding.
# The host compositor socket is bind-mounted directly into the container —
# no X11/XWayland required.
#
# Prerequisites: docker image built (docker build -t pebbleos-builder .)
# Override defaults: BOARD=qemu_flint ./run-qemu.sh
set -euo pipefail

IMAGE="${PEBBLEOS_IMAGE:-pebbleos-builder}"
BOARD="${BOARD:-qemu_emery}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
WL_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"

WAYLAND_SOCK="${RUNTIME_DIR}/${WL_DISPLAY}"
if [ ! -S "${WAYLAND_SOCK}" ]; then
    echo "error: Wayland socket not found at ${WAYLAND_SOCK}" >&2
    echo "       Is WAYLAND_DISPLAY / XDG_RUNTIME_DIR set correctly?" >&2
    exit 1
fi

# Forward PulseAudio/PipeWire compat socket for audio when available.
# Falls back to SDL dummy driver so QEMU starts without a real audio device
# (qemu_emery and qemu_flint always pass -audiodev sdl to QEMU).
AUDIO_ARGS=()
PULSE_SOCK="${RUNTIME_DIR}/pulse/native"
if [ -S "${PULSE_SOCK}" ]; then
    AUDIO_ARGS=(
        -v "${PULSE_SOCK}:/run/host-compositor/pulse/native"
        -e "PULSE_SERVER=unix:/run/host-compositor/pulse/native"
    )
else
    AUDIO_ARGS=(-e "SDL_AUDIODRIVER=dummy")
fi

# Allocate a TTY only when stdin is itself a terminal so the script also
# works when called non-interactively (CI, automated tooling, etc.).
TTY_FLAG=
[ -t 0 ] && TTY_FLAG="-t"

docker run --rm -i ${TTY_FLAG} \
    --user "$(id -u):$(id -g)" \
    -v "${SCRIPT_DIR}/data:/pebble" \
    -e "BOARD=${BOARD}" \
    -v "${WAYLAND_SOCK}:/run/host-compositor/${WL_DISPLAY}" \
    -e "XDG_RUNTIME_DIR=/run/host-compositor" \
    -e "WAYLAND_DISPLAY=${WL_DISPLAY}" \
    -e "SDL_VIDEODRIVER=wayland" \
    "${AUDIO_ARGS[@]}" \
    "${IMAGE}" \
    qemu
