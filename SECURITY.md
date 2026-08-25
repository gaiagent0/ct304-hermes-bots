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

## Bot-felelősségi körök

- **biztonsagor**: minden push titkosság-scanje + ClawSentry riasztások kezelése
- **rendszergazda**: infra változások dokumentálása ebben a repóban
