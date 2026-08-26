# ct304-hermes-bots

CT-304 (pve-ai-agent) Hermes bot-háló — 8 agent, herdr workspace-ök, képesség-alapú modell-elosztás.

> **Szanitizált repo** — nincs benne token, jelszó, API-kulcs vagy privát IP-jelszó.

## Architektúra

```
CT-304 (Debian 12 LXC, 8 GB RAM)
└── herdr server (0.8.2)
    ├── w1 "ops" workspace
    │   ├── rendszergazda   → homelab ops döntések
    │   ├── orszem          → infra összesítők
    │   ├── kutato          → arXiv / önfejlesztő kutatás
    │   └── biztonsagor     → ClawSentry audit + biztonsági őr
    └── w3 "tartalom" workspace
        ├── iro             → krónika, dokumentáció
        ├── fejleszto       → kód, technikai docs
        ├── hirado          → trend-scout, hírek
        └── kodolo          → kis kódfeladatok
```

## Modell-elosztás képesség szerint

| Bot | Modell | Indoklás |
|---|---|---|
| rendszergazda | `stealth/ox-alpha` | legkomplexebb ops döntések |
| biztonsagor | `stealth/ox-alpha` | audit elemzés |
| kutato | `meituan/longcat-2.0:free` | hosszú kontextus |
| iro | `upstage/solar-pro4:free` | írási minőség |
| hirado | `upstage/solar-pro4:free` | szövegalkotás |
| fejleszto | `poolside/laguna-s-2.1:free` | kód-specialista (nagyobb) |
| kodolo | `poolside/laguna-xs-2.1:free` | kód-specialista (gyors) |
| orszem | `stepfun/step-3.7-flash:free` | gyors flash összesítőkhöz |

Beállítás:

```bash
HERMES_HOME=/root/.hermes/profiles/<bot> hermes config set model <modell>
```

## Fájlok

| Fájl | Leírás |
|---|---|
| `hermes-bots-herdr.sh` | Idempotens építő szkript: w1/w3 workspace-ök, pane-ek, TUI indítás |
| `launch-4-profiles.sh` | 4 profil külön Hermes Desktop (Electron) ablakban — dyslexiás/GUI munka |
| `docs_RUNBOOK.md` | CT-304 Proxmox node-migrációs runbook (pve-03 → pve-02) |
| `PETS_SETUP.md` | Pets avatárok + dyslexiás font + herdr telemetry beállítása |
| `SECURITY.md` | Titok-kezelési szabályok a bot-hálóban |

## Használat

```bash
# Teljes bot-háló építése/ellenőrzése
/root/bin/hermes-bots-herdr.sh

# Csak egy workspace
/root/bin/hermes-bots-herdr.sh w1     # ops négyes
/root/bin/hermes-bots-herdr.sh w3     # tartalom négyes

# Csatlakozás SSH-ról (VNC nem kell)
ssh -t root@<ct304-ip> herdr
```

## Herdr billentyűk

- `Ctrl+B` + `1..9` — workspace váltás
- `Ctrl+B` + `b` — sidebar ki/be
- `Ctrl+B` + `?` — teljes keymap

## Működés részletesen

### Hogyan fut a herdr server (tmux host)

A herdr headless környezetben tmux-ban fut: a `hermes-bots-herdr.sh` először ellenőrzi,
hogy a `herdr status server` kimenete `status: running`-t mutat-e. Ha nem, elindítja:

```bash
tmux new-session -d -s herdr-server 'herdr'
```

A server egy detached `herdr-server` nevű tmux session-ben él, így SSH-kilépés után is fut.
A UI-hoz csatlakozni az `ssh -t root@<ct304-ip> herdr` paranccsal lehet — ez a herdr CLI-t
indítja, ami a már futó serverhez köt rá. A pane-ekben futó Hermes TUI-k a
`HERMES_HOME=/root/.hermes/profiles/<bot>` környezeti változóval indulnak, így mindegyik
a saját profilját tölti be.

### Mit csinál a hermes-bots-herdr.sh lépésenként

1. **Server biztosítása:** ha a herdr server nem fut, elindítja tmux-ban (lásd fent), 4 mp várakozás.
2. **Workspace-állapot ellenőrzése:** `herdr pane list` JSON-kimenetéből megszámolja,
   hány élő pane van az adott workspace ID előtaggal (`w1:` / `w3:`).
3. **Idempotens skip:** ha a workspace-ben már ≥ annyi pane van, amennyi bot tartozik oda (4),
   a workspace-t kihagyja (`[=] … már kész — skip`). Ezért biztonságos bármikor újrafuttatni.
4. **Pane-ek építése** (ha kell): az első bot a workspace root pane-jébe kerül (`w1:p1`),
   a továbbiakat felváltva jobbra és lefelé splittelve (2×2 grid), mindet a megfelelő
   `HERMES_HOME` env-vel.
5. **Elnevezés:** minden pane-t a bot nevére nevez át (`herdr pane rename`).
6. **TUI indítás:** minden paneba `herdr pane run` indítja a `hermes --tui`-t a saját profillal.
7. **Állapotkiírás:** a végén kilistázza az összes pane-t (workspace, label, agent_status),
   majd kiírja a csatlakozási útmutatót.

Futtatási módok:
```bash
/root/bin/hermes-bots-herdr.sh      # mindkét workspace (w1 + w3)
/root/bin/hermes-bots-herdr.sh w1   # csak ops négyes
/root/bin/hermes-bots-herdr.sh w3   # csak tartalom négyes
```

### Hibaelhárítás

**Egy pane-ből kilépett az agent (dead/üres pane):**
- Ok: a `hermes --tui` hibával lépett ki (pl. hibás config, hálózati gond a provider felé).
- Diagnózis: `herdr pane list` — a pane `agent_status` mezője mutatja; vagy nézd meg a panet.
- Javítás: futtasd újra a szkriptet — de mivel idempotens, a kész workspace-öt skippli,
  ha a pane száma még elég. Egyetlen pane újraindítása kézzel:
  ```bash
  herdr pane run w1:p1 'HERMES_HOME=/root/.hermes/profiles/rendszergazda hermes --tui'
  ```

**Teljes TUI restart (minden pane újraépítése):**
1. Zárd be az összes agent TUI-t / öld meg a workspace pane-it:
   ```bash
   herdr pane list            # pane ID-k listázása
   # pane-onként: herdr pane kill <pane_id>   (vagy a herdr UI-ból Ctrl+B + x)
   ```
2. Ha a herdr server maga akadt el:
   ```bash
   tmux kill-session -t herdr-server
   ```
3. Újraépítés:
   ```bash
   /root/bin/hermes-bots-herdr.sh
   ```

**A server fut, de a CLI nem találja:** ellenőrizd, hogy ugyanaz a user (root) és
ugyanaz a DISPLAY/tmux socket; `tmux ls`-szel győződj meg a `herdr-server` session-ről.

**RAM nyomás 8 bot mellett:** figyeld `free -m`; a migráció utáni 10 GB RAM
(lásd `docs_RUNBOOK.md`) a célállapot.

## Elvárások

- herdr ≥ 0.8.2 (`/usr/local/bin/herdr`)
- 8 Hermes profil (`HERMES_HOME=/root/.hermes/profiles/<név>`)
- tmux (a herdr UI hostolásához headless környezetben)
