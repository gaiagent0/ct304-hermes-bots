# CT 304 — Langfuse Observability (Hermes agentek monitorozása)

Ez a dokumentum leírja, hogyan kötöttük össze a CT 304 Hermes bot-hálót a
Langfuse-szal (http://10.10.40.36:3000, projekt: Hermes-CT304), hogy a
Hermes agentek működését (LLM hívások, tool callok, sessionek, subagentek)
nyomon kövessük.

> **Szanitizált:** a Langfuse kulcsok NINCSENEK ebben a fájlban. Csak a
> globális `~/.hermes/.env` tartalmazza őket (`HERMES_LANGFUSE_*` változók).

---

## Architektúra

**CÉL:** a Langfuse monitorozza a Hermes agenteket — minden conversation turn,
LLM request, tool call trace-e a Langfuse-ba megy. Ez **tracing**, nem
lekérdezés.

Hermes **beépített (bundled) Langfuse pluginja** létezik:
`plugins/observability/langfuse/` (v0.20.5-től). Opt-in — engedélyezni kell.

⚠️ **NE keverd össze a Langfuse MCP szerverrel** (`/api/public/mcp`): az
*lekérdezésre* való (a botok nézhetik a trace-eiket), de a monitorozáshoz
NEM kell. Csak a plugin kell.

---

## Beállítás (validált 2026-08-27)

### 1. Kulcsok a globális `.env`-be

```bash
# /root/.hermes/.env  (GLOBÁLIS, nem profil .env!)
HERMES_LANGFUSE_PUBLIC_KEY=pk-lf-...
HERMES_LANGFUSE_SECRET_KEY=sk-lf-...
HERMES_LANGFUSE_BASE_URL=http://10.10.40.36:3000
```

> A plugin a **globális** `~/.hermes/.env`-ből olvassa a kulcsokat. Ha a
> profil `.env`-be teszed, a plugin NEM találja meg őket.

### 2. Langfuse SDK telepítése

```bash
source /usr/local/lib/hermes-agent/venv/bin/activate
pip install langfuse
deactivate
```

### 3. Plugin engedélyezése

```bash
hermes plugins enable observability/langfuse
# → "✓ Plugin observability/langfuse enabled. Takes effect on next session."
```

A plugin **globális**: minden profilra érvényes (nem kell profilonként
engedélyezni). Hookjai: `pre/post_api_request`, `pre/post_llm_call`,
`pre/post_tool_call`, `on_session_end/finalize`, `subagent_start/stop`.

**Fail-open:** SDK / kulcs / API hiba esetén silent no-op — sosem töri meg
az agent loop-ot.

### 4. Futó sessionök újraindítása

A plugin "takes effect on next session" — a már futó TUI-kat újra kell indítani:
```bash
bash /root/hermes-bots/ct304-hermes-bots/restart-tuis.sh
```

---

## Ellenőrzés

```bash
hermes plugins list          # observability/langfuse → enabled
hermes chat -q "hello"       # majd Langfuse-ban "Hermes turn" trace
```

API ellenőrzés (base64 token = `base64(pk:sk)`):
```bash
curl -s -H "Authorization: Basic $(echo -n 'pk-lf-...:sk-lf-...' | base64)" \
  "http://10.10.40.36:3000/api/public/traces?limit=3"
# → data[] tömb, benne "Hermes turn" name
```

Validált eredmény (2026-08-27):
```
Langfuse válasz: 1 trace
  - 9417eed7d373 | Hermes turn | 2026-08-27T04:57:07.831Z
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

## Hibák, amiket NE kövess el

- ❌ Kulcsok a **profil** `.env`-be → a plugin nem találja őket. Globális legyen.
- ❌ Langfuse MCP szerver bekötése a profil configba (`mcp_servers`) → felesleges,
  a tracinget a plugin intézi. (Ezt korábban tévesen megtettük, aztán eltávolítottuk.)
- ❌ `hermes update` után a botok üres pane-okkal → a plugin újraindítás után
  aktív; `restart-tuis.sh` újraindítja a TUI-kat.
