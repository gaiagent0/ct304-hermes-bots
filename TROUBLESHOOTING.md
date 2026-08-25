# Hibakeresési kézikönyv (TROUBLESHOOTING)

A CT-304 Hermes bot-háló gyakori problémái és gyors megoldások. Minden szekció
önmagában áll, színedre szabva a „herdr telepítés”, a „ClawSentry blokkok
kezelése”, az „xterm font problémák” és a „magyar billentyűzet beállítás”.

---

## 1. herdr telepítési hibák

A `herdr` a bot-háló TUI szervere és a workspace-kezelő. Ha a
telepítés vagy a futtatás sikertelenül, akkor:

### 1.1 `herdr: parancs nem található`

- **Mi a baj?** A `/usr/local/bin/herdr` nem létezik vagy nem esik az `PATH`-ba.
- **Fix:** ellenőrizd a telepítési helyet:
  ```bash
  which herdr || ls -l /usr/local/bin/herdr
  ```
  Ha a bináris máshol van, linkeld át:
  ```bash
  ln -sf /opt/herdr/bin/herdr /usr/local/bin/herdr
  rehash
  ```
  Ha sosem telepítetted, akkor a hivatalos forrásból:
  ```bash
  curl -fsSL https://herdr.example/install.sh | sh -s -- --yes
  ```
  *(A valós URL-t cseréld ki a belső mirror vagy a herdr dokumentáció szerinti
  értékre. A fenti csupán egy sablon.)*

### 1.2 Python 3 hiány / `ModuleNotFoundError: No module named 'requests'`

- **Mi a baj?** A herdr függőségei (pl. `requests`, `psutil`) nincsenek
  feltelepítve.
- **Fix:** használd a környezetspecifikus virtuális környezetet:
  ```bash
  python3 -m venv /opt/herdr/venv
  source /opt/herdr/venv/bin/activate
  pip install -U pip
  pip install requests psutil pyfiglet
  # vagy ha van belső csomagkezelőd:
  /opt/herdr/bin/herdr install-deps
  ```

### 1.3 `XDG_RUNTIME_DIR not set` / `Failed to connect to socket`

- **Mi a baj?** A herdr szerver headless (tmux) környezetben próbál elindulni,
  de nincs beállítva a runtime directory.
- **Fix:**
  ```bash
  export XDG_RUNTIME_DIR="/run/user/$(id -u)"
  mkdir -p "$XDG_RUNTIME_DIR"
  chmod 700 "$XDG_RUNTIME_DIR"
  # úgy, hogy a tmux session is ezt látolja:
  tmux new-session -d -s herdr 'XDG_RUNTIME_DIR=/run/user/$(id -u) herdr'
  ```

### 1.4 `tmux: command not found` vagy `no server running`

- **Mi a baj?** A herdr a tmux-et használja a panelek háttérindításához.
- **Fix:**
  ```bash
  apt-get install -y tmux      # Debian/Ubuntu
  # vagy
  apk add tmux                 # Alpine
  ```
  A szerver újraindítása után:
  ```bash
  tmux kill-server 2>/dev/null; herdr status server
  ```

### 1.5 `Address already in use` (port 8080 már foglalt)

- **Mi a baj?** Egy régebbi herdr-példány vagy más szolgáltatás tartja a portot.
- **Fix:**
  ```bash
  ss -ltnp | grep ':8080'
  # Ha más folyamat tartja, azonosítsd és (ha szabad) esd meg:
  fuser -k 8080/tcp   # csak ha biztosan a te szervered
  # vagy váltj más portra:
  herdr config set server.port 8090
  ```

---

## 2. ClawSentry blokkok kezelése (curl | sh → manuális letöltés)

A **ClawSentry** a `biztonsagor` bot biztonsági őre: a kritikus parancsok
(csuccjok, jelszavak, token-generálás) ellenőrzése nélkül nem hagyja át
a futtatást. Ha egy `curl | sh` vagy bármilyen pipe-elt letöltést akarunk
futtatni, a ClawSentry **blokkolja** — és jól is teszi.

### 2.1 A blokkolás tünetei

- A parancs visszatér egy üzenettal, hogy:
  > `[ClawSentry] Pipe-elt futtatás tiltott (curl | sh). Használj manuális letöltést.`
- A ClawSentry logját a következő helyen találod:
  ```bash
  tail -n 40 /var/log/clawsentry/audit.log
  ```

### 2.2 Megoldás: manuális letöltés + ellenőrzés

A helyes munkafolyamat **soha nem `curl | sh`**:

```bash
# 1. Letöltés külön (nincs végrehajtás a csővezetégben)
curl -fsSL -o install.sh https://example.com/install.sh

# 2. SHA256 ellenőrzés (a kiadó oldalán közzétett hashsel)
sha256sum install.sh
#   pl. elvárt: a1b2c3d4... (ÍRD ÁT a valós hash-re)

# 3. GPG aláírás ellenőrzése (ha elérhető a .asc)
curl -fsSL -o install.sh.asc https://example.com/install.sh.asc
gpg --verify install.sh.asc install.sh

# 4. Csak ellenőrzés után futtatás
sh ./install.sh --yes
# vagy bash-hez: bash ./install.sh --yes
```

### 2.3 "De csak egy egyszerű script!" — miért nem megy?

Mert a ClawSentry **minden** `curl|sh`, `wget|bash` és hasonló mintát blokkolja,
független attól, hogy egy "nyomtass csak ki egy szöveget" scriptet futtatunk-e.
A biztonságos alternatíva ugyanaz, mint fenn: letöltés, ellenőrzés, futtatás.

### 2.4 Fejlesztői kivétel (csak szigorlatosan)

Ha **tudatosan** kell kivételesen átfutnia egy pipe-elt parancsnak (pl. CI
pipeline), a ClawSentry helyi konfigurációjából ideiglenesen kihúzható:

```bash
# Ideiglenes kivétel (nem ajánlott hosszú távon!)
clawsentry policy edit --allow-pipe --ttl 600   # 10 perc
# vagy egyedi rule:
echo "allow_pipe_for=curl https://példá.hu/ok" >> /etc/clawsentry/local.rules
systemctl restart clawsentry
```

> **Figyelem:** A repo soha ne tartalmazzon ClawSentry- konfigurációs
> kivételeket vagy jelszavakat! Ez a szekció csak referenciát ad.

---

## 3. xterm / terminal emulátor font problémák

A herdr TUI és a pane-ok a terminál emulátoron keresztül jelennek meg. Ha a
karakterek nem jelennek meg jól (felül- vagy lefelébomló bitmap, helyettesítő
karakterek, ? jelek), akkor a font hiányos vagy helytelen.

### 3.1 Nincs megfelelő Unicode font

- **Tünetek:** `�` helyett valós karakterek (pl. magyar ékezet) hiány, vagy
  a szegélyes táblázatok helytelenül jelennek meg.
- **Fix:** telepíts egy Unicode-kompatibilis fontot:
  ```bash
  # Debian/Ubuntu
  apt-get install -y fonts-noto fonts-noto-color-emoji

  # A herdr konfig feléllítása:
  cat >> ~/.config/herdr/config.yaml <<'EOF'
  terminal:
    font: "Noto Sans Mono"
    font_size: 11
    fallback_fonts:
      - "Noto Color Emoji"
      - "DejaVu Sans Mono"
  EOF
  ```
  A tmux pane-n belül:
  ```bash
  Ctrl+B :  # herdr command prompt
  set -g default-terminal "tmux-256color"
  set -ag terminal-overrides "xterm-256color:RGB"
  ```

### 3.2 Magyar ékezetek "???"-ként jelennek meg

- **Tünet:** A herdr vagy a bot session-ökben a magyar karakterek helyett
  `???`-t látsz.
- **Fix:** Győződj meg róla, hogy a terminál és a locale helyesek:
  ```bash
  localectl set-locale LANG=hu_HU.UTF-8
  localectl set-keymap hu
  # ha hu_HU.UTF-8 nem létezik, generáld:
  sed -i 's/^# *hu_HU.UTF-8 UTF-8/hu_HU.UTF-8 UTF-8/' /etc/locale.gen
  locale-gen
  dpkg-reconfigure locales
  ```
  Indíts újra egy shell-t és ellenőrizd:
  ```bash
  locale
  echo $LANG    # várható: hu_HU.UTF-8
  echo "Árváztűrő tömbök"  # helyesen kell megjelennie
  ```

### 3.3 Font túl kicsi vagy túl nagy a TUI-ben

- **Fix:** A herdr TUI-ban a skálázáshoz:
  ```bash
  # Ctrl+B, majd:
  :resize-pane -L 2     # szélesíts balra
  :resize-pane -R 2     # szélesíts jobbra
  :resize-pane -U 1     # magasabb felső
  # vagy a globális skála a konfigban:
  herdr config set ui.scale 1.2
  ```

---

## 4. Magyar billentyűzet beállítás

A herdr TUI, a tmux pane-ok és az egyes bot session-ök billentyűzetkezelése
magyar nyelvű bemenetre kell, hogy korrekt működjön (é, á, ő, ű st.)

### 4.1 `xev` / `setxkbmap` alapján

Ha grafikus környezetben (VNC/nagyon ritkán), a konzol kívül:
```bash
setxkbmap hu
# állandóvá téve a ~/.xsessionrc-ban vagy a display manager konfigban:
echo 'setxkbmap hu' >> ~/.xsessionrc
```

### 4.2 Konzol / SSH környezet (a leggyakoribb CT-304 eset)

A CT 304 legtöbbször **headless** (SSH-n, vagy `herdr` direkt indulással)
indul. Itt a konzol billentyűzetet kell beállítani:

```bash
# 0. ellenőrizd a jelenlegi állapotot:
cat /etc/default/keyboard
localectl status

# 1. Beállítás:
cat > /etc/default/keyboard <<'EOF'
XKBMODEL="pc105"
XKBLAYOUT="hu"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
EOF

# 2. Konzol billentyűzet frissítése:
setupcon   # vagy: dpkg-reconfigure keyboard-configuration

# 3. Aktív session-hez (azonnali hatással):
loadkeys hu
```

### 4.3 `loadkeys: couldn't find` / hiányos magyar keymap

- **Mi a baj?** A magyar keymap fájl (`/usr/share/keymaps/i386/qwertz/hu.map.gz`)
  nem települt.
- **Fix:**
  ```bash
  apt-get install -y console-data  # tartalmazza a keymap-eket
  # vagy csak a magyarat:
  apt-get install -y keyboard-configuration
  ```
  Ezután:
  ```bash
  loadkeys hu
  setupcon --save
  ```

### 4.4 SSH-n keresztüli magyar ékezet probléma

Ha az ékezetek helytelenül jelennek meg (pl. `Ã¡` helyett `á`), akkor az
**SSH kliens** és a **szerver** UTF-8 kódolása nem egyezik:

```bash
# Szerver oldalán:
dpkg-reconfigure locales    # kapcsold be a hu_HU.UTF-8-t
localectl set-locale LANG=hu_HU.UTF-8

# SSH kliens oldalán (locales/ssh_config):
#   SendEnv LANG LC_*
# A szerveren:
echo "AcceptEnv LANG LC_*" >> /etc/ssh/sshd_config
systemctl reload sshd
```

### 4.5 herdr/TUI billentyűproblémák

A herdr a következő billentyűket használja (ne konfliktusson a magyar
elrendezéssel):
| Billentyű | Funkció |
|-----------|---------|
| `Ctrl+B` | herdr prefix |
| `1..9`   | workspace váltás |
| `b`      | sidebar ki/be |
| `?`      | teljes keymap |

Ha a magyar `Ctrl+B` helyett `Ctrl+V`-t küld (nem valószínű, de előfordul),
akkor a keymap konfliktus lehet:
```bash
# Globális átállítás a herdr prefixére:
herdr config set ui.prefix "ctrl+a"
# vagy egyedi egy sessionhez a tmuxben:
tmux unbind-key ctrl+b
tmux prefix2 -n ctrl+a
```

---

## Gyakori ellenőrzési parancsok

```bash
herdr status server          # szerver fut-e?
herdr pane list              # melyen panelek élnek?
tail -n 30 /var/log/clawsentry/audit.log   # ClawSentry logok
free -h                       # memória a CT 304-n
df -h /                       # lemezterület
locale                        # nyelv/charset állapot
```

--

> Lásd még: [`README.md`](README.md) (architektúra, modell-elosztás) és
> [`docs_RUNBOOK.md`](docs_RUNBOOK.md) (CT-304 migráció, RAM skálázás).
