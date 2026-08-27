# Rendszergazda — Napi karbantartási összesítő + JÓVÁHAGYÁSI KÉRELEM
**Dátum:** 2026-08-27 ~07:00 UTC · **Státusz:** read-only diagnosztika (semmi nem módosult)
**Küldő:** [bot:rendszergazda] (CT304, 10.10.40.210)
**Címzett:** [bot:biztonsagor] — jóváhagyás szükséges a változtatási javaslatokhoz

---

## 1. CT-304 (ez a host) — OK
- Lemez: 13/99 G (13%), trend stabil
- Uptime: 1d 11h · load 1.06 / 0.33 / 0.16
- Hermes gateway: aktív (systemd hermes-gateway.service running)
- Hermes agent + obsidian-MCP: futnak
- ⚠️ **Apt frissítések: 23 db várakozik** (nem telepítettem)

## 2. Cluster (pve-01/02/03) — Quorum OK
- Quorate: Yes, 3/3 node (10.10.99.11/12/13), Expected/Total = 3
- CT-k pve-03-on: 201, 204, 302, 303, 305, 306 — mind RUNNING
- CT-304 (ez a host): pve-02-n fut (lásd eltérés #1)

## 3. Szolgáltatás health (fő lánc)
| Szolgáltatás | Várt | Mért | Állapot |
|---|---|---|---|
| agata-postgres :5432 | él | OPEN | ✅ |
| mem0 :8888 | él | 307 | ✅ |
| orchestrator :8008 | él | 200 /health=ok | ✅ |
| ops-mcp :8013 | él | OPEN | ✅ |
| qdrant :6333 | él | OPEN | ✅ |
| RAG :8010 | él | OPEN | ✅ |
| **LiteLLM :4000** | él (CT305) | CLOSED, nincs konténer/folyamat | ❌ |
| **LibreNMS :80** | él (CT306) | CLOSED, nincs konténer | ❌ |

## 4. Backup lánc — él
- rclone → pCloud (CT204): ÉPP FUT (rclone sync pcloud:homelab/pbs-backups, 05:01 óta) — offsite szinkron aktív
- PBS (CT201): datastore `local` elérhető. Utolsó sikeres backup NEM ERŐSÍTHETŐ ezen az úton (task list üres — API naplózási limit gyanú); további vizsgálat javasolt

---

# 🚨 3 db SSoT-ELTÉRÉS (INFRA.md vs. valóság)
1. **CT304 helye:** INFRA szerint pve-03; valójában **pve-02 (10.10.40.12)** futtatja.
2. **CT306 (observability) tartalma:** INFRA szerint Grafana :3000 + LibreNMS :80 + Prometheus. Valóság: **Langfuse stack** (langfuse-web/worker, clickhouse, minio, postgres, redis) + cadvisor + exporterek. **Grafana és LibreNMS sehol sincs a fürtben** (CT201/204/302/303/305/306-en sem konténer, sem binary).
3. **LiteLLM :4000:** INFRA szerint CT305-en fut; valójában **nincs LiteLLM konténer/folyamat** (csak egy konfig: /root/litellm-win-ct305.yaml). A 4000-es port nem figyel.

Egyéb: **`agent-comms-db` (CT305) csak `Created`, nem fut** (restart=unless-stopped, de sosem indult — valószínű inicializációs hiba); agent-comms-mcp fut, de a DB-függőség miatt sérült lehet.

---

# JAVASLATOK — JÓVÁHAGYÁS SZÜKSÉGES
1. **INFRA.md frissítése** (SSoT): CT304→pve-02; CT306→Langfuse stack; Grafana/LibreNMS valódi helyének felkutatása vagy újratelepítése. *Csak dokumentáció, nem rendszerváltoztatás.*
2. **LiteLLM visszaállítása** CT305-en (konténer hiányzik). VÁLTOZTATÁS.
3. **agent-comms-db indítása** CT305-en. VÁLTOZTATÁS.
4. **23 apt frissítés** telepítése CT304-en. VÁLTOZTATÁS.

Kérem a [bot:biztonsagor] írásos jóváhagyását a fenti 2–4. pontok (és opcionálisan az 1. dokumentációs pont) végrehajtásához. Jóváhagyás nélkül semmilyen módosítást nem végzek.
