---
cycle_id: "20260510-manual-sagememory-worktree-repair"
title: "Fix: manualna naprawa rozjechanej pamieci SageMemory w worktree"
workflow: fix
phase: intake
status: intake
created: 2026-05-10
updated: 2026-05-10
owner: alexostl
needs-triage: true
priority: P1
source: "conversation"
suggested_workflow: fix
related:
  - ".sage-memory/"
  - "/Users/alexostl/Developer/_worktrees/codex/38fb/sage-selfhost/.sage-memory/"
  - "/Users/alexostl/Developer/_worktrees/codex/75f2/sage-selfhost/.sage-memory/"
  - "/Users/alexostl/Developer/_worktrees/codex/951c/sage-selfhost/.sage-memory/"
  - ".sage/docs/memory-branch-worktree-operating-model.md"
  - ".sage/docs/learn-sage-selfhost-branch-worktree-model.md"
scope:
  - ".sage/work/20260510-manual-sagememory-worktree-repair/*"
  - ".sage/decisions.md"
  - ".sage-memory/**"
---

# Fix: manualna naprawa rozjechanej pamieci SageMemory w worktree

## State

**Current phase:** intake - capture only. Implementacja i migracja nie zostaly
rozpoczete.

**Next step:** Wejsc w osobny `/sage:fix`, potwierdzic aktualny stan wszystkich
`.sage-memory` w main repo i worktree, zrobic backupy, a dopiero potem
zaproponowac bezpieczna procedurę merge/import.

## Problem

Projektowe SageMemory w `sage-selfhost` rozgalezilo sie fizycznie przez
worktree-local `.sage-memory/memory.db`.

Zaobserwowane lokalizacje:

- `/Users/alexostl/Developer/sage-selfhost/.sage-memory/`
- `/Users/alexostl/Developer/_worktrees/codex/38fb/sage-selfhost/.sage-memory/`
- `/Users/alexostl/Developer/_worktrees/codex/75f2/sage-selfhost/.sage-memory/`
- `/Users/alexostl/Developer/_worktrees/codex/951c/sage-selfhost/.sage-memory/`

Jesli ktorys ephemeral worktree zostanie skasowany, findings zapisane tylko w
jego lokalnym DB/WAL moga zniknac. To jest problem fizycznej lokalizacji
project memory, nie argument za semantycznym przeniesieniem wszystkiego do
global memory.

## Desired outcome

`sage-selfhost` ma miec jedno wybrane canonical project SageMemory, a istniejace
worktree-local bazy maja zostac recznie sprawdzone i scalone.

Docelowo po tej manualnej naprawie:

- zadne wartosciowe entries z worktree-local DB nie gina;
- main repo i istniejace worktree wskazuja na to samo project memory albo maja
  jasny pointer/symlink do canonical location;
- `.sage-memory/` pozostaje gitignored i nie trafia do commita;
- semantyka zostaje `scope: project`, nie `scope: global`.

## Candidate repair steps

1. **Inventory**
   - wypisac wszystkie `.sage-memory` katalogi dla main repo i worktree;
   - zanotowac rozmiary `memory.db`, `memory.db-wal`, `memory.db-shm` i czasy
     modyfikacji;
   - sprawdzic, ktory DB powinien byc canonical source of truth.

2. **Backup**
   - skopiowac kazdy katalog `.sage-memory` do timestamped backup location
     przed jakimkolwiek merge/import;
   - nie usuwac lokalnych DB bez jawnego potwierdzenia.

3. **Compare / export**
   - porownac wpisy w tabeli `memories` po `id`, `title`, `content_hash` lub
     dostepnym odpowiedniku;
   - uwzglednic WAL, zeby nie zgubic ostatnich zapisow;
   - przygotowac liste entries obecnych tylko w worktree-local DB.

4. **Merge / import**
   - zaimportowac brakujace entries do canonical project memory przez
     SageMemory API, jesli to mozliwe;
   - jesli potrzebny jest SQLite-level import, najpierw pokazac plan i ryzyka;
   - polegac na deduplikacji content/hash, ale nie zakladac jej bez
     weryfikacji.

5. **Replace local stores with pointers**
   - po potwierdzonym merge zastapic worktree-local `.sage-memory` pointerem
     albo symlinkiem do canonical project memory;
   - jesli symlink/pointer nie jest jeszcze standardem w alex-os, zostawic
     prace na poziomie manualnej naprawy i nie projektowac resolvera.

## Boundary

Ten cycle nie projektuje resolvera SageMemory i nie dodaje `sage memory doctor`.
Nie naprawia tez inicjalizacji nowych worktree w alex-os-dev. Tamten temat jest
osobno uchwycony w:

- `/Users/alexostl/Developer/alex-os-dev/.sage/work/20260510-new-worktree-initialization-script/manifest.md`

Ten cycle dotyczy tylko manualnej naprawy istniejacego rozjazdu pamieci w
`sage-selfhost`.
