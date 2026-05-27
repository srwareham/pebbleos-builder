#!/usr/bin/env bash
set -euo pipefail

export HOME=/pebble/home
mkdir -p "${HOME}"

# ---------------------------------------------------------------------------
# Activate SDK (sets PATH entries for arm-none-eabi, qemu, sftool)
# ---------------------------------------------------------------------------
# shellcheck source=/opt/pebbleos-sdk/env.sh
source "${PEBBLEOS_SDK_HOME}/env.sh"

# ---------------------------------------------------------------------------
# Trust the source directory regardless of who owns it on the host
# ---------------------------------------------------------------------------
# -- Only add safe directory if not already present.
git config --global --get-all safe.directory 2>/dev/null | grep -qxF "${PEBBLEOS_SRC}" || \
    git config --global --add safe.directory "${PEBBLEOS_SRC}"

# ---------------------------------------------------------------------------
# Venv — create at the bind-mounted path on first run, then reuse.
# We can't copy the seed wholesale because its scripts have shebangs pointing
# to the seed path. Instead we create a fresh venv (correct shebangs) and
# copy only the site-packages from the seed so nothing needs downloading.
# ---------------------------------------------------------------------------
if [ ! -f "${VENV_PATH}/bin/pip" ]; then
    echo "Initializing Python venv..."
    python3 -m venv "${VENV_PATH}"
    # Populate with pre-installed packages from the image seed
    cp -a "${VENV_SEED}"/lib/*/site-packages/. "${VENV_PATH}"/lib/*/site-packages/
    # Copy console_scripts from the seed, rewriting their shebangs to point at
    # the new venv so they work from the bind-mounted path.
    for f in "${VENV_SEED}/bin"/*; do
        fname="$(basename "$f")"
        dest="${VENV_PATH}/bin/${fname}"
        [ -d "$f" ] && continue      # skip __pycache__ and similar dirs
        [ -e "$dest" ] && continue   # keep python/pip/activate created by venv
        cp "$f" "$dest"
        if head -1 "$dest" 2>/dev/null | grep -q "^#!${VENV_SEED}"; then
            sed -i "1s|^#!${VENV_SEED}|#!${VENV_PATH}|" "$dest"
        fi
    done
fi

# ---------------------------------------------------------------------------
# Source tree — clone if not present (supports optional host volume mount)
# ---------------------------------------------------------------------------
if [ ! -d "${PEBBLEOS_SRC}/.git" ]; then
    echo "PebbleOS source not found at ${PEBBLEOS_SRC} — cloning..."
    git clone --recurse-submodules https://github.com/coredevices/PebbleOS.git "${PEBBLEOS_SRC}"
else
    echo "Using existing PebbleOS source at ${PEBBLEOS_SRC}"
    git -C "${PEBBLEOS_SRC}" submodule update --init --recursive
fi

cd "${PEBBLEOS_SRC}"

# ---------------------------------------------------------------------------
# Editable local packages — all dependencies are pre-installed in the image
# so this is fast with no network access needed.
# ---------------------------------------------------------------------------
pip install -q \
    -e python_libs/pebble-commander \
    -e python_libs/pulse2 \
    -e python_libs/pebble-loghash

# ---------------------------------------------------------------------------
# Configure, then dispatch to the requested command (default: build)
# ---------------------------------------------------------------------------
COMMAND="${1:-build}"

echo "Configuring for board: ${BOARD}"
./waf configure --board "${BOARD}"

if [ "${COMMAND}" = "qemu" ]; then
    echo "Building for QEMU..."
    ./waf build
    echo "Launching QEMU emulator..."
    exec ./waf qemu
fi

# Default: build + bundle
echo "Building..."
./waf build

echo "Bundling..."
./waf bundle

# ---------------------------------------------------------------------------
# Report output location
# ---------------------------------------------------------------------------
BUILD_DIR="${PEBBLEOS_SRC}/build"
PBZ=$(find "${BUILD_DIR}" -name "*.pbz" 2>/dev/null | sort | head -1)
HOST_PBZ="./data${PBZ#/pebble}"
echo ""
echo "========================================"
echo "Build complete."
echo ""
echo "The firmware bundle can be sideloaded onto your watch from the Pebble"
echo "mobile app. The .pbz file is available at:"
echo ""
echo "  ${PBZ}"
echo "    (in the container)"
echo ""
echo "  ${HOST_PBZ}"
echo "    (on your local system, assuming -v \"\$(pwd)/data:/pebble\")"
echo "========================================"
