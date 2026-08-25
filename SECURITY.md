# Biztonsági szabályok (bot-háló)

## SOHA ne kerüljön repóba

- API token / kulcs (GITHUB_TOKEN, BRAVE, TAVILY, stb.)
- Jelszó (basic auth, VNC, dashboard)
- `.env` fájl tartalma
- Privát kulcsok (SSH, PGP)

## Kötelező ellenőrzés push előtt

```bash
grep -riE "(token|password|jelszo|secret)\s*=" <módosított fájlok>
```

Ha bármi egyezik → NE commitold.

## Token-kezelés

- A `GITHUB_TOKEN` csak a profil `.env`-jében él (`HERMES_HOME=<profil>/.env`)
- Push URL-be soha ne legyen beégetve — ha mégis belekerült:
  `git remote set-url origin <tiszta-url>` és token revokálás GitHubon

## ClawSentry guard

A CT-304-en futó guard blokkolja:
- `curl | sh` minták (download-and-execute)
- reverse shell signature-kat (`/dev/tcp`, socket)

Helyes minta: **manuális letöltés** (`curl -o` majd külön futtatás).

## Bot-felelősségi mátrix

| Bot | Felelősség a repóban | Push-jog | Kritikus felületek |
|---|---|---|---|
| **biztonsagor** | SECURITY.md karbantartása, titkosság-scan minden push előtt, ClawSentry riasztások kezelése, incidenskezelés vezetése | igen (biztonsági docs) | Vaultwarden, NPM, AdGuard, Tailscale, CT305 AI portok |
| **rendszergazda** | Infra változások dokumentálása (RUNBOOK, README), just-script leírások | igen (infra docs) | Proxmox node-ok, CT-k, backup/PBS |
| **egyéb botok** | Csak saját profil-dokumentáció | csak review után | saját szolgáltatásuk |

Szabályok:
- Minden bot push előtt futtassa a grep-alapú titkosság-scant.
- A **biztonsagor** bármely push-t visszautasíthat, ha titokgyanús tartalmat lát.
- Változtatós műveletekhez (nem read-only) a biztonsagor explicit jóváhagyása kell.

## Incidenskezelési folyamat — token került a repóba

Ha egy token / jelszó / kulcs bekerül a repóba (commit, push URL, log):

1. **Azonnali revokálás** (legfontosabb lépés, percek kérdése):
   - GitHub: Settings → Developer settings → revoke token; új generálása a profil `.env`-jébe.
   - Egyéb szolgáltatás (Brave, Tavily, stb.): dashboardon revokálás + új kulcs.
2. **Történelem tisztítása** — a revokálás önmagban nem elég, de a maradvány is eltávolítandó:
   - `git remote set-url origin <tiszta-url>` (ha az URL-ben élt),
   - `git filter-repo` vagy BFG Repo-Cleaner a fájltörténetből,
   - force-push + minden klón újraklónozása.
3. **Visszagörgetés / hatásvizsgálat**:
   - Mennyi ideig volt kint? (`git log`, push időpontja óta)
   - Volt-e idegen hozzáférés nyoma? (GitHub audit log, auth.log)
4. **Dokumentálás**: rövid incidens-jegyzőkönyv a SECURITY.md mellé (dátum, mi történt, intézkedések), **a titok értékét SOHA nem írjuk bele**.
5. **Felelős**: a felfedező bot jelenti a **biztonsagor**-nak, aki vezeti az intézkedéseket; a rendszergazda végzi a technikai revokálást/tisztítást a biztonsagor jóváhagyásával.
