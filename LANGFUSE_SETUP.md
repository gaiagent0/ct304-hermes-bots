# CT 304 — Langfuse Observability (Hermes agentek monitorozása)

Ez a dokumentum leírja, hogyan kötöttük össze a CT 304 Hermes bot-hálót a
Langfuse-szal (http://10.10.40.36:3000, projekt: Hermes-CT304), hogy a
Hermes agentek működését (LLM hívások, tool callok, sessionek, subagentek)
nyomon kövessük.

> **Szanitizált:** a Langfuse kulcsok NINCSENEK ebben a fájlban. Csak a
> globális `~/.hermes/.env` tartalmazza őket (`HERMES_LANGFUSE_*` változók),
> ÉS minden bot-profil saját `/root/.hermes/profiles/<név>/.env`-je is
> (lásd alább, miért).

---

## Architektúra

**CÉL:** a Langfuse monitorozza a Hermes agenteket — minden conversation turn,
LLM request, tool call trace-e a Langfuse-ba megy. Ez **tracing**, nem
lekérdezés.

Hermes **beépített (bundled) Langfuse pluginja** létezik:
`plugins/observability/langfuse/`. Opt-in — engedélyezni kell.

⚠️ **NE keverd össze a Langfuse MCP szerverrel** (`/api/public/mcp`): az
*lekérdezésre* való (a botok nézhetik a trace-eiket), de a monitorozáshoz
NEM kell. Csak a plugin kell.

**Adatbázis-réteg:** a Langfuse állapot PostgreSQL-ben, az analitika
ClickHouse-ban fut. A CT 304 környezetben ezek a **pve-03** gépen vannak
(docker-host). A környezetben MÁR VAN Prometheus + ClickHouse — a Langfuse
ehhez a meglévő infrastruktúrához csatlakozik, nem új DB-t telepít.

---

## ⚠️ 2026-08-27 KORREKCIÓ — a korábbi "globális" állítás HIBÁS

A korábbi verzió azt írta, a plugin GLOBÁLIS és a globális `~/.hermes/.env`-ből
olvassa a kulcsokat, nem kell profilonként bekötni. A VALÓSÁG (tényleges bekötés
után ellenőrizve, üres Langfuse hiba esetén kiderült):

1. **A plugin NEM globális.** A 9 bot-profil `config.yaml` `plugins.enabled`
   listájába KÜLÖN be kell venni az `observability/langfuse`-t:
   ```yaml
   plugins:
     enabled:
       - clawsentry-guard
       - observability/langfuse
   ```
2. **A botok NEM öröklik a default `.env` Langfuse kulcsait.** A plugin a
   futó profil SAJÁT `.env`-jét olvassa. Tehát minden bot
   `/root/.hermes/profiles/<név>/.env`-jébe be KELL írni a 3 kulcsot
   (PUBLIC/SECRET/BASE_URL), különben **SILENT-DROP** történik: a Langfuse
   üres marad, NINCS hibaüzenet. (A default `~/.hermes/.env` a te/én profilhoz
   elegendő, de a botoknál kötelező a per-profil másolat.)
3. **A `langfuse` SDK NINCS a gateway pythonjában alapból.** Telepíteni kell
   a gateway folyamat python értelmezőjével (uv-vezérelt runtime, PEP 668 →
   `--break-system-packages` szükséges). A régi `/usr/local/lib/hermes-agent/venv`
   útvonal NEM létezik már.
4. **Az `ox-alpha-free` / `stealth/ox-alpha` modellek NEM léteznek** (404 a
   Nous API-n). A botok modelljei átírva: rendszergazda/biztonsagor →
   `tencent/hy3:free`, a többi megmaradt a saját :free modelljénél.

---

## Beállítás (validált 2026-08-27, KORRIGÁLT)

### 1. Kulcsok — globális + per-bot

```bash
# /root/.hermes/.env  (a fő profilhoz / hozzád)
HERMES_LANGFUSE_PUBLIC_KEY=pk-lf-...
HERMES_LANGFUSE_SECRET_KEY=sk-lf-...
HERMES_LANGFUSE_BASE_URL=http://10.10.40.36:3000
```

ÉS minden bot-profil `.env`-je (hiányában silent-drop):
```bash
# /root/.hermes/profiles/<név>/.env  (rendszergazda, proxi66, kodolo, iro,
#   fejleszto, hirado, biztonsagor, orszem, kutato)
HERMES_LANGFUSE_PUBLIC_KEY=pk-lf-...
HERMES_LANGFUSE_SECRET_KEY=sk-lf-...
HERMES_LANGFUSE_BASE_URL=http://10.10.40.36:3000
```
Automatizálható: a default `.env` Langfuse sorainak átmásolása minden
bot-profil `.env`-jébe (backup után).

### 2. Langfuse SDK telepítése a gateway pythonjába

```bash
GW=$(pgrep -f "gateway run" | head -1)
PY=$(readlink -f /proc/$GW/exe)
$PY -m pip install langfuse -U --break-system-packages
$PY -c "import langfuse; print(langfuse.__version__)"   # ellenőrzés
```
(A gateway pythonja a Hermes saját, uv-vezérelt runtime-a; a `--break-system-packages`
a PEP 668 védelem feloldása. A langfuse egy izolált csomag.)

### 3. Plugin engedélyezése (profilonként)

A `default` profilnál a `config.yaml plugins.enabled` lista elegendő. A bot-
profiloknál a `clawsentry-guard` mellé add hozzá az `observability/langfuse`-t
(config.yaml), vagy:
```bash
HERMES_HOME=/root/.hermes/profiles/<név> hermes plugins enable observability/langfuse
```

Hookjai: `pre/post_api_request`, `pre/post_llm_call`, `pre/post_tool_call`,
`on_session_end/finalize`, `subagent_start/stop`.

**Fail-open:** SDK / kulcs / API hiba esetén silent no-op — sosem töri meg
az agent loop-ot. (Ezért üres Langfuse esetén NINCS hiba → ellenőrizd az
SDK-t és a per-bot .env-t!)

### 4. Gateway + TUI újraindítása

A plugin + új .env csak gateway restart után él:
```bash
hermes gateway restart --all
bash /root/hermes-bots/ct304-hermes-bots/restart-tuis.sh
```

---

## Ellenőrzés

```bash
hermes plugins list          # observability/langfuse → enabled
hermes chat -q "hello"       # majd Langfuse-ban "Hermes turn" trace
```

API ellenőrzés (a `.env`-ből olvasott pk:sk basic auth):
```bash
source /root/.hermes/.env
curl -s -u "$HERMES_LANGFUSE_PUBLIC_KEY:$HERMES_LANGFUSE_SECRET_KEY" \
  "$HERMES_LANGFUSE_BASE_URL/api/public/traces?limit=3"
# → data[] tömb, benne "Hermes turn" name, ÉS több különböző sessionId
#   (botok + cron_* + fő profil) = mindenki monitorozva van
```

---

## Opcionális tuning (env változók)

```bash
HERMES_LANGFUSE_ENV=production        # environment tag
HERMES_LANGFUSE_RELEASE=v1.0.0        # release tag
HERMES_LANGFUSE_SAMPLE_RATE=0.5       # sample 50% of traces
HERMES_LANGFUSE_MAX_CHARS=12000       # max chars per field
HERMES_LANGFUSE_CAPTURE=sanitized     # metadata | sanitized | full
HERMES_LANGFUSE_DEBUG=true            # verbose plugin logging
```

`HERMES_LANGFUSE_CAPTURE` vezérli a content exportját:
- `metadata`: csak strukturális adatok (ID, role, tool name, token, cost)
- `sanitized` (default): content secret-redaction után, truncálva
- `full`: nyers content (explicit opt-in — traces tartalmazzák a memóriát is)

---

## Első feladat: Langfuse v3 → v4 frissítés

A szerver jelenleg **v3.224.4**. A v4 natívan a ClickHouse-ra épül (165× gyorsabb
analitika), PostgreSQL 16 + ClickHouse szükséges. Mivel a pve-03-on MÁR van
ClickHouse, a migráció a MEGLÉVŐ ClickHouse példány újrakötése + Postgres
frissítés + migrációs script. KOCKÁZAT: a meglévő 9 bot + cron trace-ek
megőrzése → előbb MENTÉS (pg_dump + ClickHouse snapshot) a `homelab-backup-stack`
szerint. Változtatás → a biztonsági őr (biztonsagor bot) ÍRÁSOS jóváhagyása
szükséges, csak tervet + javaslatot tehetsz.

A frissítés UTÁN beköthetők:
- **LLM Connections** (OpenAI/Azure/Anthropic/Google/Bedrock vagy OpenAI-
  kompatibilis endpoint) → Playground, LLM-as-a-Judge, Prompt Experiments.
  Ingyenes/helyi modell is használható (Nous :free, Ollama qwen3:8b).
- **LLM-as-a-Judge**: egy modell automatikusan pontozza a bot trace-eket
  (minőség, szerep-tartás, tool-call helyesség, nyelv). API-n versionozható.
- **Prompt Management**: bot promptok (SOUL.md, system promptok) verziózása, A/B.

---

## Hibák, amiket NE kövess el

- ❌ Kulcsok CSAK a globális `.env`-be → a botok NEM látják őket, silent-drop.
  Minden bot-profil `.env`-jébe is be kell írni.
- ❌ Plugin csak a default profilban engedélyezve → a botok nem küldenek
  trace-t. Minden bot-profil `plugins.enabled`-jébe be kell venni.
- ❌ SDK nélkül hagyni → a plugin silent-dropol (nincs hiba!). Ellenőrizd
  az importot a gateway pythonjával.
- ❌ Langfuse MCP szerver bekötése a profil configba (`mcp_servers`) → felesleges,
  a tracinget a plugin intézi.
- ❌ `hermes update` után a botok üres pane-okkal → a plugin újraindítás után
  aktív; `restart-tuis.sh` újraindítja a TUI-kat.
