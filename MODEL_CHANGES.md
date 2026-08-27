# CT 304 — Modell változások (2026-08-27)

## stealth/ox-alpha megszűnése

A `stealth/ox-alpha` modell **eltűnt a Nous Portal katalógusából** (2026-08-23
körül). A GitHub Issue #93030 szerint tools-enabled kéréseknél üres választ
adott, és `ox-alpha-free` via zen/go/v1 `network_error/503`-at. A Hermes
kivette a listából → `Model 'stealth/ox-alpha' was not found in this provider's
model listing` hiba.

**Nem lejárati dátum** — a modell mögötti infra megszűnt / degradálódott.

## Váltás: stealth/ox-alpha → stealth/ox-alpha-free

A két "profi" profilban (rendszergazda, biztonsagor) átírtuk a modellt:
```yaml
model:
  provider: nous
  default: stealth/ox-alpha-free   # korábban: stealth/ox-alpha
  base_url: https://inference-api.nousresearch.com/v1
```

**Ellenőrzés (2026-08-27):**
```
rendszergazda: hermes chat -q "..." → exit 0, ox-alpha-free válaszolt (26s)
biztonsagor:   hermes chat -q "..." → exit 0, ox-alpha-free válaszolt (17s)
```
Nincs "not found" hiba. Az `ox-alpha-free` él és működik (gyengébb mint az
eredeti ox-alpha, de stabilabb, mint a hy3:free fallback).

## Miért nem más free modell?

A `rendszergazda`/`biztonsagor` a legfontosabb profilok (infra audit,
biztonsági gatekeeper). Az `ox-alpha-free` a legjobb elérhető stealth opció
nekik — a `hy3:free` (ami korábban fallback-ként futott) gyengébb volt az
összetett döntési feladatoknál.

A többi 6 profil már free modellt használt (solar pro4, laguna, step 3.7
flash, longcat 2.0) — ezeken nem változtattunk.

## Bot teljesítmény elemzés (modell → profil illeszkedés)

| Profil | Modell | Feladat | Minőség |
|--------|--------|---------|---------|
| rendszergazda | hy3:free (fallback) → ox-alpha-free | INFRA audit, delegálás | JÓ — reális hibafeltárás, nem módosít jóváhagyás nélkül |
| biztonsagor | hy3:free (fallback) → ox-alpha-free | gatekeeper, audit | JÓ (passzív) — helyes készenléti protokoll |
| orszem | step 3.7 flash | monitoring | OK |
| kutato | longcat 2.0 | kutatás | OK (beragadt TTY hurokba, de az infra hiba, nem modell) |
| iro | solar pro4 | írás | OK (passzív) |
| fejleszto | laguna s 2.1 | kódolás | JÓ — opciók felajánlása |
| hirado | solar pro4 | hírek/riport | KIVÁLÓ — helyesen diagnosztálta az ox-alpha megszűnését |
| kodolo | laguna xs 2.1 | kódolás | OK |

**Következtetés:** a free modellek megfelelően teljesítenek a profiljaiknak.
Az `ox-alpha-free` visszaállította a két profi profil eredeti szintjét.
