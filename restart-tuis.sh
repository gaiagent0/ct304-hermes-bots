#!/usr/bin/env bash
# 8 bot TUI újraindítása a meglévő herdr pane-okba (agent_status: unknown -> working/idle)
set -u
declare -A PANE2PROF=(
  [w1:p1]=rendszergazda
  [w1:p2]=orszem
  [w1:p3]=kutato
  [w1:p4]=biztonsagor
  [w3:p1]=iro
  [w3:p2]=fejleszto
  [w3:p3]=hirado
  [w3:p4]=kodolo
)
for pane in "${!PANE2PROF[@]}"; do
  prof="${PANE2PROF[$pane]}"
  echo "[*] $pane -> $prof TUI indítása"
  herdr pane run "$pane" "HERMES_HOME=/root/.hermes/profiles/$prof hermes --tui" 2>&1 | tail -1
  sleep 2
done
echo "Várakozás a TUI betöltésére (10s)..."
sleep 10
echo ""
echo "=== Állapot ==="
herdr pane list 2>/dev/null | python3 -c "
import json,sys
d=json.load(sys.stdin)
for p in d['result']['panes']:
    if p['label']:
        print(f\"  {p['pane_id']:8s} {p['label']:14s} {p['agent_status']}\")
"