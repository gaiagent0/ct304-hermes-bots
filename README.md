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
| `docs_RUNBOOK.md` | CT-304 Proxmox node-migrációs runbook (pve-03 → pve-02) |
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

## Elvárások

- herdr ≥ 0.8.2 (`/usr/local/bin/herdr`)
- 8 Hermes profil (`HERMES_HOME=/root/.hermes/profiles/<név>`)
- tmux (a herdr UI hostolásához headless környezetben)
