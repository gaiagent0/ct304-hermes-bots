#!/usr/bin/env bash
# Egyetlen Hermes Desktop ablak indítása egy profilhoz.
# Használat: bash launch-one-desktop.sh <profil>
set -u
export DISPLAY="${DISPLAY:-:98}"
export ELECTRON_DISABLE_SANDBOX=1
export LIBGL_ALWAYS_SOFTWARE=1
APP=/usr/local/lib/hermes-agent/apps/desktop/release/linux-unpacked/Hermes
P="${1:?Használat: $0 <profil>}"
HOME_DIR=/root/.hermes/profiles/$P
LOG=/tmp/hermes-desktop-$P.log
echo "[*] $P desktop indítása (DISPLAY=$DISPLAY, log: $LOG)"
# GPU process crash ellen: software GL + in-process GPU + disable gpu sandbox
exec env HERMES_HOME="$HOME_DIR" "$APP" \
  --disable-gpu \
  --disable-software-rasterizer \
  --disable-gpu-sandbox \
  --use-gl=swiftshader \
  --use-angle=swiftshader \
  --in-process-gpu \
  --no-sandbox \
  --disable-dev-shm-usage
