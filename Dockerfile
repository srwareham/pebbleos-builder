FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV BOARD=qemu_emery
ENV PEBBLEOS_SRC=/pebble/pebbleos
ENV PEBBLEOS_SDK_HOME=/opt/pebbleos-sdk
ENV VENV_PATH=/pebble/venv
ENV VENV_SEED=/opt/pebbleos-venv-seed

# System-level dependencies required by PebbleOS
RUN apt-get update && apt-get install -y \
    bison \
    ccache \
    clang \
    curl \
    flex \
    gcc \
    gcc-multilib \
    gettext \
    git \
    gperf \
    libfreetype6-dev \
    libglib2.0-dev \
    libgtk-3-dev \
    libncurses-dev \
    librsvg2-bin \
    make \
    nodejs \
    npm \
    openocd \
    python3-dev \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Install PebbleOS SDK to a fixed prefix so PATH is predictable.
# --defaults skips interactive prompts; --prefix pins the install location.
RUN curl -LsSf https://github.com/coredevices/PebbleOS-SDK/releases/latest/download/pebbleos-sdk-installer.sh \
    | sh -s -- --prefix "$PEBBLEOS_SDK_HOME" --defaults

# Build the venv at the seed path — /pebble is a bind mount and doesn't exist
# at image build time, so VENV_PATH can't be used here directly.
RUN python3 -m venv "$VENV_SEED"

# Pre-install all Python dependencies.
# requirements.txt excludes the `-e python_libs/...` editable packages (their
# paths don't exist at build time), so we sparse-clone just python_libs to
# install them as regular packages. This pulls in their sub-dependencies
# (construct, transitions, etc.) so nothing needs downloading at runtime.
RUN curl -sSfL https://raw.githubusercontent.com/coredevices/PebbleOS/refs/heads/main/requirements.txt \
    | grep -v '^-e ' > /tmp/requirements.txt \
    && "$VENV_SEED/bin/pip" install --upgrade pip \
    && "$VENV_SEED/bin/pip" install --ignore-requires-python -r /tmp/requirements.txt \
    && rm /tmp/requirements.txt

RUN git clone --depth=1 --filter=blob:none --sparse https://github.com/coredevices/PebbleOS.git /tmp/pebbleos \
    && git -C /tmp/pebbleos sparse-checkout set python_libs \
    && "$VENV_SEED/bin/pip" install \
        /tmp/pebbleos/python_libs/pebble-commander \
        /tmp/pebbleos/python_libs/pulse2 \
        /tmp/pebbleos/python_libs/pebble-loghash \
    && rm -rf /tmp/pebbleos

# Both the venv and the SDK are on PATH; venv takes precedence for python/pip.
ENV PATH="$VENV_PATH/bin:$PEBBLEOS_SDK_HOME/bin:$PATH"

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
