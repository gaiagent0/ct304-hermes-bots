# CT 304 — Pets, Dyslexia font, herdr telemetry

Ez a dokumentum leírja, hogyan állítottuk be a CT 304 (pve-ai-agent) Hermes
bot-hálót 2026-08-26 után: dyslexiabarát fontok, herdr keményítés, pets
avatárok minden profilba, és 4 profil külön chatablakban (Hermes Desktop).

> **Szanitizált:** nincs token, jelszó vagy privát IP a fájlokban.

---

## 1. Dyslexiás font stratégia (alapkészlet, nincs új app)

Két felület → két font. Mindkettő már telepítve van a rendszeren.

| Felület | Font | Útvonal | Miért |
|---|---|---|---|
| Nem-TUI (desktop app, web dashboard) | **Atkinson Hyperlegible** | `/usr/local/share/fonts/atkinson/` | Braille Institute, szakértői #1 diszlexiabarát sans-serif. Alapkészlet, nem kell letölteni. |
| TUI / herdr grid (terminál) | **OpenDyslexicMono** | `/usr/share/fonts/opentype/opendyslexic/OpenDyslexicMono-Regular.otf` | A TUI monospace-t igényel. Ez a monospace + diszlexiabarát változat. |

**FONTOS:** Az Atkinson Hyperlegible NEM monospace → a TUI-ban NEM használható
(szétesne a pane elrendezés). A TUI-ban kötelező az OpenDyslexicMono.

Ellenőrzés:
```bash
fc-list | grep -i "atkinson\|opendyslexicmono"
```

### Elavult: dyslexia-shim (NE használd)
A `apps/desktop/dyslexia-shim/` (951 KB-os Electron-main bundle + launcher) egy
elhalt kísérlet volt. Sehol nincs bekötve, nem ad valódi dyslexiatámogatást.
Eltávolítva: `/tmp/hermes-dyslexia-shim-backup-20260826/`.

---

## 2. Profil színkülönbség (működik)

Minden profilnak saját skin-je van (`<HERMES_HOME>/skins/<profil>.yaml`),
különböző színekkel. Ez megkülönbözteti a botokat a gridben:

| Profil | Szín |
|---|---|
| rendszergazda | cián (#00BCD4) |
| biztonsagor | piros (#CC0000) |
| fejleszto | rózsaszín (#FF1493) |
| kodolo | zöld (#76B900) |
| kutato | lila/piros (#FF2975) |
| orszem | smaragd (#1bff80) |
| iro | barack (#FFB7C5) |
| hirado | barna/arany (#DD8E35) |

---

## 3. herdr telemetry kikapcsolása

A herdr alapból "phone-home"-ol (verzió + távoli manifest ellenőrzés). Offline
környezetben felesleges. `/root/.config/herdr/config.toml`:

```toml
[update]
version_check = false
manifest_check = false
```

Érvényesítés (panék maradnak élve):
```bash
herdr config check
herdr server reload-config
```

---

## 4. Pets avatárok (minden profilba)

A `hermes pets` a petdex galériából telepíti a profil saját
`<HERMES_HOME>/pets/<slug>/` könyvtárába. Bekapcsolás: `display.pet.enabled: true`.

Profil → pet párosítás (mindegyik különböző):

| Profil | Pet slug |
|---|---|
| rendszergazda | bartholomew-bear |
| biztonsagor | ai-workbot |
| fejleszto | glitchcat |
| kodolo | big-orange-cat |
| kutato | zichao-bear-2 |
| orszem | white-dog |
| iro | panda-penguin |
| hirado | gourmand-slugcat |

Telepítés:
```bash
HERMES_HOME=/root/.hermes/profiles/rendszergazda hermes pets install bartholomew-bear --select
```

Ellenőrzés: `HERMES_HOME=/root/.hermes/profiles/rendszergazda hermes pets doctor` → `✓ ready`.

Pets = tisztán kosmetikai, nincs hatással a prompt cache-re vagy tokenekre.

---

## 5. 4 profil indítása külön chatablakban (Hermes Desktop)

`launch-4-profiles.sh` — 4 profil külön Electron ablakban (nem a herdr grid).

Követelmények:
- **Xvfb :99** futnia kell (headless X server). Ha nincs:
  ```bash
  Xvfb :99 -screen 0 1920x1080x24 -ac +extension RANDR >/tmp/xvfb.log 2>&1 &
  ```
- **`--no-sandbox`** kötelező (root alatt az Electron nem indul anélkül).
- Közvetlen release build indítása (nem `hermes desktop`, ami rebuildel):
  `/usr/local/lib/hermes-agent/apps/desktop/release/linux-unpacked/Hermes`

A 4 profil: `rendszergazda fejleszto iro kutato` (a leggyakrabban szükségesek).
Módosítsd a `PROFS` tömböt a scriptben, ha másik 4 kell.

```bash
bash /root/hermes-bots/ct304-hermes-bots/launch-4-profiles.sh
```

Ellenőrzés: `ps aux | grep "[H]ermes" | grep -v python` → 4 Electron pid.
