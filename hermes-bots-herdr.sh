#!/usr/bin/env bash
# Hermes botok herdr-ben, KÉT workspace-ben (4+4 bot).
#
# Használat:
#   /root/bin/hermes-bots-herdr.sh          -> mindkét workspace építése/ellenőrzése
#   /root/bin/hermes-bots-herdr.sh w1       -> csak az "ops" workspace (rendszergazda, orszem, kutato, biztonsagor)
#   /root/bin/hermes-bots-herdr.sh w3       -> csak a "tartalom" workspace (iro, fejleszto, hirado, kodolo)
#
# Csatlakozás:
#   SSH-n:  ssh root@10.10.40.210   majd:   herdr
#   A workspaces közt váltás: prefix (Ctrl+B) + szám (1 = ops, 2-3 = többi), vagy az oldalsávban kattintás.
#   Sidebar ki/be: Ctrl+B majd b

set -u
export DISPLAY="${DISPLAY:-:99}"
TARGET="${1:-all}"

# --- Server biztosan fusson ---
if ! herdr status server 2>/dev/null | grep -qi "status: running"; then
  echo "[*] herdr server indítása..."
  tmux new-session -d -s herdr-server 'herdr' 2>/dev/null || true
  sleep 4
fi

build_workspace() {
  local WS_ID="$1"; shift
  local PROFILES=("$@")
  local N=$#

  # Már felépített workspace? (4 élő pane a saját ID előtaggal)
  local EXISTING
  EXISTING=$(herdr pane list 2>/dev/null | python3 -c "
import json,sys
d=json.load(sys.stdin)
ps=[p for p in d['result']['panes'] if p['pane_id'].startswith('$WS_ID:')]
print(len(ps))")
  if [ "${EXISTING:-0}" -ge "$N" ]; then
    echo "[=] $WS_ID workspace már kész ($EXISTING pane) — skip"
    return 0
  fi

  echo "[+] $WS_ID workspace építése: ${PROFILES[*]}"
  # Az első pane a workspace root-ja
  local P1="${WS_ID}:p1"
  herdr pane rename "$P1" "${PROFILES[0]}" >/dev/null

  declare -A PANES=( ["0"]="$P1" )
  for i in $(seq 1 $((N-1))); do
    local p="${PROFILES[$i]}"
    local col=$(( i % 2 ))
    local BASE DIR
    if [ "$col" -eq 1 ]; then BASE=${PANES[$((i-1))]}; DIR=right
    else BASE=${PANES[$((i-2))]}; DIR=down; fi
    local NEW
    NEW=$(herdr pane split "$BASE" --direction $DIR \
      --env "HERMES_HOME=/root/.hermes/profiles/$p" 2>/dev/null | \
      python3 -c "import json,sys; print(json.load(sys.stdin)['result']['pane']['pane_id'])" 2>/dev/null)
    [ -n "$NEW" ] || { echo "HIBA: split sikertelen ($p)"; return 1; }
    herdr pane rename "$NEW" "$p" >/dev/null
    PANES[$i]="$NEW"
  done

  for i in $(seq 0 $((N-1))); do
    local p="${PROFILES[$i]}"
    herdr pane run "${PANES[$i]}" "HERMES_HOME=/root/.hermes/profiles/$p hermes chat" >/dev/null 2>&1
  done
  sleep 5
  echo "[✓] $WS_ID kész: ${PROFILES[*]}"
}

case "$TARGET" in
  w1|ops)
    build_workspace w1 rendszergazda orszem kutato biztonsagor ;;
  w3|tartalom)
    build_workspace w3 iro fejleszto hirado kodolo ;;
  all|"")
    build_workspace w1 rendszergazda orszem kutato biztonsagor
    build_workspace w3 iro fejleszto hirado kodolo ;;
  *) echo "Ismeretlen cél: $TARGET (w1|w3|all)"; exit 1 ;;
esac

echo ""
echo "Állapot:"
herdr pane list 2>/dev/null | python3 -c "
import json,sys
d=json.load(sys.stdin)
for p in d['result']['panes']:
    ws='W1' if p['pane_id'].startswith('w1') else 'W3'
    print(f\"  {ws} {p.get('label') or '(üres)':16s} {p.get('agent_status')}\")"

cat <<'EOF'

Csatlakozás:
  Windows Terminalból:  ssh -t root@10.10.40.210 herdr
  Workspace váltás:     Ctrl+B + 1..9  (vagy az oldalsávon kattintás)
  Sidebar ki/be:        Ctrl+B + b
  Pane váltás:           egérkattintás vagy Ctrl+B + nyíl
EOF
