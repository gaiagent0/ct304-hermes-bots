# CT 304 — Architektúra és stabil felület

## Stabil megoldás: herdr grid

A CT 304 Hermes bot-háló **herdr multiplexer** alatt fut, 8 bot pane-nel.
Ez a STABIL megoldás — minden bot él, színesen különválasztva, Langfuse
monitorozással.

```
ssh -t root@10.10.40.210 herdr
```

### Bot grid elrendezés
- **w1 workspace:** rendszergazda, orszem, kutato, biztonsagor
- **w3 workspace:** iro, fejleszto, hirado, kodolo

### Parancsok
- Indítás: `bash /root/bin/hermes-bots-herdr.sh`
- TUI újraindítása (pl. hermes update után): `bash /root/hermes-bots/ct304-hermes-bots/restart-tuis.sh`
- Csatlakozás: `ssh -t root@10.10.40.210 herdr`
- Workspace váltás: `Ctrl+B + 1..9`
- Pane váltás: egérkattintás vagy `Ctrl+B + nyíl`

### Miért herdr és nem desktop ablakok?
A Hermes Desktop (Electron) ablakok **instabilak** ezen a host-on:
- A frissített Electron/Chromium verzióban a **GPU process crash-el**
  (`FATAL: GPU process isn't usable. Goodbye.`)
- `--disable-gpu` + `--use-gl=swiftshader --in-process-gpu` mellett is csak
  1 ablak maradt életben, a többi 3 GPU/memória miatt meghalt
- A `nohup`/`&` háttérbe helyezés a shell-policy miatt SIGKILL-et kap

A herdr grid **nem használ X szervert** (headless TUI terminálban), ezért
nem érinti a GPU/Xvfb probléma. Ezért a herdr a hivatalos stabil felület.

## Komponensek

| Komponens | Állapot | Megjegyzés |
|-----------|---------|------------|
| herdr grid (8 bot) | ✅ STABIL | Elsődleges felület |
| Langfuse plugin | ✅ AKTÍV | `plugins/observability/langfuse` (bundled) |
| ox-alpha-free modellek | ✅ AKTÍV | rendszergazda, biztonsagor |
| Desktop ablakok (Electron) | ❌ INSTABIL | Ne használd — GPU crash |
| Xvfb | ⚠️ Nem kell | Csak desktop ablakhoz kellene |

## hermes update

A `hermes update` **egyszer** fut, és az egész telepítésre vonatkozik (kód +
venv + minden profil). Nem kell profilonként futtatni. Az update után:
1. Állítsd le a gridet (`herdr server stop`)
2. `hermes update`
3. Indítsd újra (`hermes-bots-herdr.sh` + `restart-tuis.sh`)

Utolsó update: 2026-08-27, `main @ 1a66134404` (v0.20.5).
