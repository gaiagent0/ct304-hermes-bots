#!/usr/bin/env bash
# Ujrainditja a hermes chat-et minden meglevo herdr pane-ben (nem epit uj pane-t).
# Hasznos, ha a pane-ek mar leteznek, de ures shell van bennuk (pl. crash utan).
set -u

declare -A P=(
  [w1:p1]=rendszergazda [w1:p2]=orszem [w1:p3]=kutato [w1:p4]=biztonsagor
  [w3:p1]=iro [w3:p2]=fejleszto [w3:p3]=hirado [w3:p4]=kodolo
)

for pane in "${!P[@]}"; do
  name="${P[$pane]}"
  herdr pane run "$pane" "HERMES_HOME=/root/.hermes/profiles/$name hermes chat" >/dev/null 2>&1
  echo "  $pane -> $name elinditva"
done

sleep 6
echo ""
echo "Allapot:"
herdr pane list 2>/dev/null | python3 /root/hermes-bots/ct304-hermes-bots/_pane_status.py
