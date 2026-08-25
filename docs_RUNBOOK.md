# CT 304 (pve-ai-agent) migrálása pve-02-re + RAM skálázás — RUNBOOK

> **Vezetői összefoglaló**
>
> **Mit csinálunk?** A CT 304 (`pve-ai-agent`) konténert áttelepítjük a túlterhelt `pve-03` csomópontról a kapacitással rendelkező `pve-02`-re, és a rendelkezésre álló RAM-ot 4 GB-ról 10 GB-ra bővítjük.
>
> **Miért van szükség rá?**
> - A `pve-03` jelenleg 78%-os RAM-kihasználtsággal fut (túlterhelt).
> - A `pve-02` csak 27%-os — van szabad kapacitás.
> - A 4 GB-os RAM korlát OOM (Out-of-Memory) hibákat okozott.
>
> **Mi a hatás?**
> - A migráció során a CT 304 leáll (a futó Hermes session megszakad).
> - Újraindul a `pve-02`-n, ugyanazzal az IP-vel (`10.10.40.210/24`).
> - Visszaállítás után a teljes 10 GB RAM áll rendelkezésre.
>
> **Mennyi idő?** Az online migráció (snapshot+restore) pár perc — a legtöbb időt az adatmásolás és a bootolás veszi igénybe.
>
> **Kinek/dove?** Bármelyik másik node-ról (pve-01 vagy pve-03), vagy a Proxmox web UI-ból futtatható.

---

## 1. Cluster állapot (valós, 2026-08-25)

| Node | IP | RAM | Foglaltság | Megjegyzés |
|------|------|-----|----------|------------|
| pve-01 | 10.10.40.11 | 16.6 GB | 57% | — |
| **pve-02** | **10.10.40.12** | **8.2 GB** | **27%** | **🎯 CÉL** |
| pve-03 | 10.10.40.13 | 16.0 GB | 78% | 📍 Jelenlegi elhelyezés |

- **Quorum:** 3 node, quorate (OK)
- **CT 304:** `pve-ai-agent`, rootfs = `local-zfs` (subvol), IP `10.10.40.210/24`

---

## 2. Végrehajtási lépések

> **Futtatható:** bármelyik másik node-ról (pve-01 vagy pve-03), vagy a Proxmox web UI-ból.

### 2.1. Előkészítés — Rollback pont (opcionális)

Ha biztonsági mentést szeretnél készíteni a migráció előtt:

```bash
vzdump 304 --storage pbs-server --mode snapshot --compress zstd
```

### 2.2. Migráció pve-02-re

Online migráció (snapshotos másolás — a CT leáll, majd újraindul a célon):

```bash
pct migrate 304 pve-02 --online
```

> ⚠️ **FIGYELEM:** A migráció **LEÁLLÍTJA** a CT 304-et. A futó Hermes session megszakad. A CT újraindul a `pve-02`-n ugyanazon IP-vel (`10.10.40.210`).

### 2.3. RAM bővítés (4 GB → 10 GB)

```bash
pct set 304 -memory 10240
```

> A `pve-02`-n van hely: 8.2 GB összesen, jelenleg ~2.2 GB foglalt.

### 2.4. CPU finomhangolás (opcionális)

```bash
# Swap marad 2048 MB, cores 6 — ha többre van szükség:
pct set 304 -cores 6
```

---

## 3. Fontos tudnivalók

- **Migráció típusa:** `local-zfs` → `local-zfs` (azonos típus, támogatott). A `pve-02`-n létezik `local-zfs` (0% használat).
- **Online migráció jellege:** LXC-nél snapshot+restore, nem folyamatos élő futás (ellentétben a VM migrációival).
- **Visszavonhatóság:** PBS mentés nélkül is visszatelepíthető: `pct migrate 304 pve-03`.

---

## 4. Migráció utáni lépések

Miután a CT a `pve-02`-n fut és 10 GB RAM-mal rendelkezik:

1. **RAM ellenőrzése:**
   ```bash
   free -m
   ```

2. **Botok újraindítása:**
   ```bash
   # Light (tmux alapú):
   /root/bin/hermes-bots-tmux.sh rendszergazda orszem kutato biztonsagor

   # Vagy valódi chat UI (grid):
   GRID=2x2 /root/bin/hermes-bots-grid.sh rendszergazda orszem kutato biztonsagor
   ```

3. **Diszlexia-barát betűtípus (opcionális):**
   ```bash
   apt install fonts-opendyslexic
   # ~/.config/fontconfig/conf.d/60-dyslexic.conf
   fc-cache -fv
   ```
   Részletek és CSS: `/root/.hermes/4BOT_CONTINUATION.md`

---

## 5. Ellenőrzőlista

A migráció sikerességének ellenőrzéséhez:

- [ ] `pct status 304` → CT fut a `pve-02`-n
- [ ] `ssh root@10.10.40.210 'free -m'` → 10 GB RAM látható
- [ ] `pct migrate` parancs nem adott hibát
- [ ] A CT IP-je nem változott (`10.10.40.210/24`)
- [ ] Hermes botok elérhetők (tmux vagy grid session)
- [ ] (Opcionális) PBS backup létezik a `pbs-server` datastore-on
- [ ] (Opcionális) Diszlexia-barát betűtípus telepítve

---

## 6. Források

- Proxmox dokumentáció: `pct migrate` / `pct set`
- Hermes 4-bot + diszlexia terv: `/root/.hermes/4BOT_CONTINUATION.md`
