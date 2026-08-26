#!/usr/bin/env bash
# 4 profil külön-külön Hermes Desktop ablakban (külön chatablak).
# Közvetlenül a release buildet indítjuk (nem hermes desktop -> nincs rebuild).
# --no-sandbox KELL, mert root-ként futunk.
set -u
export DISPLAY="${DISPLAY:-:99}"
export ELECTRON_DISABLE_SANDBOX=1
export LIBGL_ALWAYS_SOFTWARE=1

APP=/usr/local/lib/hermes-agent/apps/desktop/release/linux-unpacked/Hermes
PROFS=(rendszergazda fejleszto iro kutato)

for p in "${PROFS[@]}"; do
  HOME_DIR=/root/.hermes/profiles/$p
  LOG=/tmp/hermes-desktop-$p.log
  echo "[*] $p desktop indítása (log: $LOG)"
  HERMES_HOME="$HOME_DIR" nohup "$APP" --disable-gpu --no-sandbox --disable-dev-shm-usage >"$LOG" 2>&1 &
  sleep 3
done

sleep 5
echo ""
echo "Futó Hermes desktop ablakok (pid + profil):"
for p in "${PROFS[@]}"; do
  pid=$(pgrep -f "Hermes.*$p" 2>/dev/null | head -1)
  echo "  $p -> pid ${pid:-N/A}"
done
echo ""
echo "Log ellenőrzés (rendszergazda, utolsó 5 sor):"
tail -5 /tmp/hermes-desktop-rendszergazda.log 2>/dev/null