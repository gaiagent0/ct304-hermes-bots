# CT 304 (pve-ai-agent) migrálása pve-02-re + RAM skálázás — RUNBOOK

**Cél:** CT 304 átvitele a zsúfolt pve-03-ról a szabad pve-02-re, és a RAM bővítése
(4 GB -> 10 GB), hogy megszűnjön az OOM a 4-botos ablakos tervnél.

**Cluster (valós állapot, 2026-08-25):**
- pve-01 = 10.10.40.11 (RAM 16.6GB, 57% hasznalt)
- pve-02 = 10.10.40.12 (RAM 8.2GB, 27% hasznalt)  <-- CEL
- pve-03 = 10.10.40.13 (RAM 16.0GB, 78% hasznalt)  <-- JELENLEGI HELY
- Quorum: 3 node, quorate (OK)
- CT 304 = pve-ai-agent, rootfs = local-zfs (subvol), IP 10.10.40.210/24

## LÉPÉSEK (futtasd bármelyik mas node-rol, vagy a pve webuil-bol)
# 0. (opcionális) rollback pont: PBS backup pve-02 PBS datastore-ra
vzdump 304 --storage pbs-server --mode snapshot --compress zstd

# 1. Migráció pve-02-re (online = snapshotos másolás, CT leáll->újraindul célon)
#    Futtatható pve-01 vagy pve-03 node-rol:
pct migrate 304 pve-02 --online

# 2. RAM emelés (10 GB) — pve-02-n van hely (8.2GB össz, jelenleg 2.2GB foglalt)
pct set 304 -memory 10240

# 3. (swap marad 2048, cores 6) — ha kell több cores:
#    pct set 304 -cores 6

## FONTOS
- A migráció LEÁLLÍTJA a CT 304-et -> az ezen a gépen futó Hermes session megszakad.
  Újraindul pve-02-n ugyanazon IP-vel (10.10.40.210), onnan folytatható.
- local-zfs -> local-zfs migráció támogatott (azonos típus). pve-02-n létezik local-zfs (0% hasznalt).
- `pct migrate --online` LXC-nél snapshot+restore, nem folyamatos élő futás mint a VM-nél.
- PBS mentés nélkül is visszavonható: `pct migrate 304 pve-03` (vissza).
- Ellenőrzés utána: pct status 304 ; ssh root@10.10.40.210 'free -m'

## FOLYTATÁS (miután a CT pve-02-n fut és 10GB RAM-mal):
1. free -m  -> ellenőrizd az új RAM-ot
2. /root/bin/hermes-bots-tmux.sh rendszergazda orszem kutato biztonsagor   (light)
   vagy valódi chat UI-hoz: GRID=2x2 /root/bin/hermes-bots-grid.sh rendszergazda orszem kutato biztonsagor
3. Diszlexia-barát: apt install fonts-opendyslexic ; ~/.config/fontconfig/conf.d/60-dyslexic.conf ; fc-cache -fv
   (részlet + CSS: /root/.hermes/4BOT_CONTINUATION.md)

## FORRÁSOK
- Proxmox docs: pct migrate / pct set
- Hermes 4-bot + dyslexia terv: /root/.hermes/4BOT_CONTINUATION.md
