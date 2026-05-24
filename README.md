# Docker pebbleos-builder

Build PebbleOS firmware using docker.

## TL;DR

```sh
git clone https://github.com/srwareham/pebbleos-builder-docker.git
cd pebbleos-builder-docker

docker build -t pebbleos-builder .

mkdir -p ./data
# Build firmware for Pebble Time 2 by default, see Picking the Right Board section to change
docker run --rm -v "$(pwd)/data:/pebble" -e BOARD=obelix_pvt pebbleos-builder
```

When it finishes, grab `./data/pebbleos/build/*.pbz` and sideload it onto your watch via the Pebble app.

## What this does

1. **Build the image** (one-time setup) — installs the toolchain and pre-downloads Python dependencies into the image.
2. **Run the container** — downloads the PebbleOS source into `./data/pebbleos/`, compiles it, and saves build artifacts there. The Python environment is persisted in `./data/venv/` so nothing needs to be re-downloaded between runs.
3. **Subsequent runs** — skip the source download and rebuild only what changed.

You can alternatively mount any local directory that has your working copy of the PebbleOS source (note it needs submodules, e.g. `git clone --recurse-submodules https://github.com/coredevices/PebbleOS ./data/pebbleos`).

## Build output

The `.pbz` firmware bundle is what you need to install on your watch. By default, it is found in the directory:

```
./data/pebbleos/build/
```


The filename encodes the board and version, e.g. `normal_obelix_pvt_v4.9.179_slot0.pbz`. Additional build artifacts (ELF, raw binary, etc.) are also in `./data/pebbleos/build/`.

## Installing on your watch

Enable developer mode in the Pebble mobile app (iOS or Android), then open the `.pbz` file from `./data/pebbleos/build/` and sideload it. No cable needed.

## Picking the right Board

Change `-e BOARD=...` to match your device:

| Product | `BOARD` |
|---------|---------|
| Pebble 2 Duo | `asterix` |
| Pebble Time 2 | `obelix_pvt` |
| Pebble Round 2 | `getafix_dvt2` |
| QEMU emulator — Pebble Time | `qemu_emery` *(default)* |
| QEMU emulator — Pebble 2 | `qemu_flint` |
| QEMU emulator — Pebble Time Round | `qemu_gabbro` |

## Already have the source?

If you have the `pebbleos` source code locally, mount it directly while still mounting `./data`:

```sh
docker run --rm \
  -v "$(pwd)/data:/pebble" \
  -v "/path/to/your/pebbleos:/pebble/pebbleos" \
  -e BOARD=obelix_pvt \
  pebbleos-builder
```

The more specific mount (`/pebble/pebbleos`) takes precedence over the broader one, so your local source is used while `./data/venv` still provides the cached Python environment. The container detects the existing repo and skips cloning.
