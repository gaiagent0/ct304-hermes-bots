# ct304-hermes-bots

CT-304 (pve-ai-agent) Hermes bot-háló — 8 agent, herdr workspace-ök,
képesség-alapú modell-elosztás, natív kanban-delegálás és Langfuse v4
observability.

> **Szanitizált repo** — nincs benne token, jelszó, API-kulcs vagy privát
> IP-jelszó.

## Architektúra

```
CT-304 (Debian 12 LXC, 8 GB RAM)
└── herdr server (0.8.2)            # stabil headless TUI grid (8 bot pane)
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

CT-306 (observability)              # Langfuse v4.22.0 adatbázis-réteg
└── Postgres 17 + ClickHouse 26.7.1 + Redis + MinIO

Kanban board "ct304-team"           # delegálás / jóváhagyás gerince
└── percenkénti `hermes kanban dispatch` (cron) → worker-profilok
```

## Bot profil struktúra: SOUL.md + AGENTS.md

Minden gridbot (kutato, iro, orszem, fejleszto, kodolo, hirado,
rendszergazda, biztonsagor) mostantól kétfájlos profil-struktúrát használ:

| Fájl | Szerep |
|------|--------|
| `SOUL.md` | Identitás + stílus (rövid, karcsúsított). Ki a bot, hogyan fogalmaz, mit nem tesz soha. |
| `AGENTS.md` | Rutin, handoff-szabályok, Változtatási zár, cron-guardrail, Langfuse-tudás, skill-lista. |

A Hermes az `AGENTS.md`-t a `terminal.cwd` könyvtárból tölti be (NEM a profil
mappából), ezért mindegyik profil `config.yaml`-jában explicit
`terminal.cwd` van beállítva a saját profil-mappájára. Ez garantálja, hogy a
bot a megfelelő `AGENTS.md`-t töltse be induláskor.

## Delegálás és jóváhagyás: hermes kanban board `ct304-team`

A csapat delegálásának és módosító-művelet jóváhagyásának natív gerince a
**`ct304-team` kanban board** (nem peer-chat, nem manuális átadás):

- **Dispatch:** percenkénkénti crontab futtatja a `hermes kanban dispatch`-t.
  A gateway-be épített auto-dispatch *nem* indul el ebben a Hermes build-ben,
  ezért a cron-alapú dispatch a működőképes megoldás.
- **Disponent-claim:** a `ct304-team` boardot egyetlen gateway dispatch-eli
  (a proxi66 profil `kanban.dispatch_in_gateway: false`, így csak worker, nem
  dispatcher — elkerüli a claim race-t).
- **Bizonyított handoff-láncok** (kanban-native):
  - `kutato → iro` — kutatás után `kanban_create` + `kanban_request_review`
  - `fejleszto → kodolo` — kód után `kanban_create` + `kanban_request_review`
- Módosító infrastruktúra-változtatás esetén a rendszergazda → biztonsagor
  jóváhagyási protokoll továbbra is érvényes (lásd Változtatási zár az
  AGENTS.md-ben).

## Observability: Langfuse v4

- **Langfuse v3.224.4 → v4.22.0** frissítve (CT306-on).
- Mód: `events_only` (csak trace-események, payload nélkül — adatvédelmi
  okokból), teljes backfill lefutott.
- Projekt: `Hermes-CT304` — minden bot session_id alapján szétválaszthatóan
  ír ugyanabba a projektbe.
- A Langfuse plugin NEM globális: minden profil `config.yaml`
  `plugins.enabled` listájában külön szerepel az `observability/langfuse`.

## proxi66 gateway: systemd unit

A `proxi66` profil gateway-e most **systemd unit** alatt fut:

- Unit: `hermes-gateway-proxi66.service`
- Flag: `--external-supervisor` — szükséges, mert a `gateway run` alapból
  daemonizálódik, ami `systemd Type=simple` alatt kilépne/elválna.
- Ez a gateway a `ct304-team` board dispatcher-e (lásd fent).

## Modell-elosztás képesség szerint

> A pontos modell-hozzárendelés profilonként a `config.yaml` `model.default`
> mezőjében van — ez a táblázat tájékoztató, és a build-állapottól függően
> eltérhet tőle. A mértékadó forrás mindig a profil `config.yaml`-ja.

| Bot | Modell (tájékoztató) | Indoklás |
|---|---|---|
| rendszergazda | `tencent/hy3:free` | komplex ops döntések, ingyenes kör |
| biztonsagor | `tencent/hy3:free` | audit elemzés, ingyenes kör |
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
| `archive/2026-08-pre-cleanup/` | A 2026-08-28 takarítás előtti régi anyagok (lásd alább) |

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

A herdr headless környezetben tmux-ban fut: a `hermes-bots-herdr.sh` először
ellenőrzi, hogy a `herdr status server` kimenete `status: running`-t mutat-e.
Ha nem, elindítja:

```bash
tmux new-session -d -s herdr-server 'herdr'
```

A server egy detached `herdr-server` nevű tmux session-ben él, így
SSH-kilépés után is fut. A UI-hoz csatlakozni az
`ssh -t root@<ct304-ip> herdr` paranccsal lehet — ez a herdr CLI-t indítja,
ami a már futó serverhez köt rá. A pane-ekben futó Hermes TUI-k a
`HERMES_HOME=/root/.hermes/profiles/<bot>` környezeti változóval indulnak,
így mindegyik a saját profilját tölti be.

### Mit csinál a hermes-bots-herdr.sh lépésenként

1. **Server biztosítása:** ha a herdr server nem fut, elindítja tmux-ban
   (lásd fent), 4 mp várakozás.
2. **Workspace-állapot ellenőrzése:** `herdr pane list` JSON-kimenetéből
   megszámolja, hány élő pane van az adott workspace ID előtaggal
   (`w1:` / `w3:`).
3. **Idempotens skip:** ha a workspace-ben már ≥ annyi pane van, amennyi bot
   tartozik oda (4), a workspace-t kihagyja (`[=] … már kész — skip`). Ezért
   biztonságos bármikor újrafuttatni.
4. **Pane-ek építése** (ha kell): az első bot a workspace root pane-jébe kerül
   (`w1:p1`), a továbbiakat felváltva jobbra és lefelé splittelve (2×2 grid),
   mindet a megfelelő `HERMES_HOME` env-vel.
5. **Elnevezés:** minden pane-t a bot nevére nevez át (`herdr pane rename`).
6. **TUI indítás:** minden paneba `herdr pane run` indítja a `hermes --tui`-t
   a saját profillal.
7. **Állapotkiírás:** a végén kilistázza az összes pane-t
   (workspace, label, agent_status), majd kiírja a csatlakozási útmutatót.

Futtatási módok:
```bash
/root/bin/hermes-bots-herdr.sh      # mindkét workspace (w1 + w3)
/root/bin/hermes-bots-herdr.sh w1   # csak ops négyes
/root/bin/hermes-bots-herdr.sh w3   # csak tartalom négyes
```

### Hibaelhárítás

**Egy pane-ből kilépett az agent (dead/üres pane):**
- Ok: a `hermes --tui` hibával lépett ki (pl. hibás config, hálózati gond a
  provider felé).
- Diagnózis: `herdr pane list` — a pane `agent_status` mezője mutatja; vagy
  nézd meg a panet.
- Javítás: futtasd újra a szkriptet — de mivel idempotens, a kész
  workspace-öt skippli, ha a pane száma még elég. Egyetlen pane újraindítása
  kézzel:
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

**A server fut, de a CLI nem találja:** ellenőrizd, hogy ugyanaz a user
(root) és ugyanaz a DISPLAY/tmux socket; `tmux ls`-szel győződj meg a
`herdr-server` session-ről.

**RAM nyomás 8 bot mellett:** figyeld `free -m`; a migráció utáni 10 GB RAM
(lásd `docs_RUNBOOK.md`) a célállapot.

## Repo karbantartás

A 2026-08-28 takarítás során a `/root/hermes-bots/` régi, elavult anyagai az
`archive/2026-08-pre-cleanup/` alá kerültek. Új dokumentációt és szkriptet
ide, a repo gyökérébe tegyél; a nem használt régi cuccot ne tartsd a fő
ágban.

## Elvárások

- herdr ≥ 0.8.2 (`/usr/local/bin/herdr`)
- 8 Hermes profil (`HERMES_HOME=/root/.hermes/profiles/<név>`), mind
  `SOUL.md` + `AGENTS.md` párossal, explicit `terminal.cwd`-vel
- Langfuse v4.22.0 (CT306)
- `hermes kanban dispatch` percenkénti cron a `ct304-team` boardhoz
- tmux (a herdr UI hostolásához headless környezetben)

## Hermes build

- Utolsó update: 2026-08-28, `main @ a9611f3c6f` (v0.20.5 utáni 62 commit).
  A v0.20.5 baseline 2026-08-27-en (`main @ 1a66134404`) volt; a frissítés
  62 committot hozott fel a main ágra.
