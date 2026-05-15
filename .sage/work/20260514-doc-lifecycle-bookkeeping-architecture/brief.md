---
title: "Brief: lifecycle, decisions i bookkeeping bez token bloat"
cycle_id: "20260514-doc-lifecycle-bookkeeping-architecture"
workflow: architect
phase: brief
status: completed
created: 2026-05-14
updated: 2026-05-14
approved_at: "2026-05-14"
approved_by: "alexostl"
---

# Brief: lifecycle, decisions i bookkeeping bez token bloat

## Round 1 - Vision

Chcemy zaprojektowac prostszy model `.sage`, w ktorym agent szybko rozumie
aktywny stan projektu bez czytania calej historii.

Docelowy stan:

- `sage status` i session-start czytaja malo.
- Agent ufa manifestom jako source-of-truth dla state.
- Bogate body manifestu zostaje, bo jest najlepszym ludzkim opisem problemu.
- `decisions.md` przechowuje realne decyzje, a nie kazdy krok procesu.
- Completed cycles sa audytowalne, ale mozna naprawiac czysty bookkeeping bez
  sztucznego follow-up cycle.
- Reopen istnieje tylko jako natychmiastowa korekta w tej samej aktywnej
  rozmowie.

Sukces nie oznacza "mniej dokumentow". Sukces oznacza, ze zwykle pytanie o
status nie wymaga archeologii w `.sage/work`, `.sage/decisions.md`, git logach
i transcriptach.

## Round 2 - Constraints

### Zakres w architekturze

- Lifecycle completed/reopen/follow-up/reconciliation.
- Atomic closeout bookkeeping.
- Formalizacja istniejacego live status/work-index mechanizmu zamiast budowy
  nowego indeksu.
- Decisions capture policy i retention policy.
- Closeout validation jako glowne miejsce wykrywania niespojnego completed
  state.

### Poza zakresem

- Sage Wiki / alex-os migration.
- `summary.md` jako nowy standard dla cykli.
- Duza evidence archive/log migration.
- `sage doctor` jako primary UX.
- `sage status` warnings jako primary consistency mechanism.
- Nowy persistent cache work-index na start.

### Ustalenia zatwierdzone w rozmowie

- `.sage/decisions.md` trzyma 50 najnowszych decyzji.
- Starsze decyzje ida do jednego `.sage/decisions-archive.md`.
- Archive ma byc newest-first, jesli implementacyjnie jest to tylko niewiele
  trudniejsze od append-only.
- Archive read jest search-first: `rg`, potem maly fragment. Full archive read
  tylko z nazwanym powodem.
- W Git worktree rotacja decyzji nie rusza archive; overflow ponad 50 wpisow w
  worktree jest legalny i tymczasowy.
- Work-index to formalizacja obecnego live scan manifestow, nie nowy dokument
  ani recznie edytowany plik.
- Manifest body zostaje bogate, ale `## State` musi byc spojne z frontmatter.
- Bookkeeping-only reconciliation completed cycle nie wymaga follow-up cycle ani
  decisions entry.
- Reopen tylko natychmiastowo w tej samej aktywnej rozmowie.
- Closeout validation w closeout path; bez `sage doctor`, bez `sage status`
  warnings i na start bez hooka.

## Round 3 - Gaps

### G1 - Exact decision capture policy

Trzeba zapisac, ktore zdarzenia trafiaja do `.sage/decisions.md`, a ktore tylko
do manifestu, planu, root-cause, QA/reportu albo logu.

Wstepny kierunek:

- Do decisions: finalnie zaakceptowany root cause, finalnie zaakceptowany
  plan/scope, scope expansion, final closeout, trwale zasady projektowe,
  decyzje uzytkownika zmieniajace kierunek/priorytet/ownership.
- Nie do decisions: auto-review verdict jako osobny wpis, `needs revision`,
  intermediate checkpoint, kazda rewizja planu/root-cause, completion
  checkpoint przed approval, pure bookkeeping reconciliation.

### G2 - Rotation mechanics

Trzeba zaprojektowac minimalny mechanizm rotacji:

- current file newest-first, max 50 decisions;
- archive newest-first;
- rotacja automatyczna poza linked worktrees;
- linked worktrees moga przekroczyc 50 wpisow bez bledu;
- archive nie jest ruszane w worktree.

### G3 - Closeout validation shape

Trzeba okreslic, czy closeout validation bedzie tylko workflow checklist, malym
helperem, czy testowalnym shell helperem wywolywanym przez workflow/tooling.

Minimalna walidacja:

- `status: completed` idzie z `phase: completed`;
- `## State` nie zawiera aktywnego next step;
- folded/sibling intake ma `resolution` / `folded_into`;
- brak leftover `completion-checkpoint`, `verify`, `commit/push pending`.

### G4 - Live work-index contract

Trzeba nazwac i uszczelnic istniejacy kontrakt `sage status --json`:

- czyta manifest frontmatter, nie pelne artefakty;
- nie czyta `harness-run-*`, raw `.jsonl`, `.stderr`, target snapshots;
- nie wprowadza nowego persistent cache, dopoki live scan jest szybki;
- jezeli kiedys cache bedzie potrzebny, miejsce zgodne z konwencja to
  `.sage/.cache/...`.

### G5 - Migration boundaries

Trzeba rozdzielic architekture od migracji istniejacego repo:

- architektura definiuje docelowy kontrakt;
- osobny plan okresli, jak bezpiecznie obciac `.sage/decisions.md` do 50 wpisow
  i przeniesc reszte do `.sage/decisions-archive.md`;
- migracja nie moze gubic audytu ani wymuszac recznej pracy Alexa.

## Proposed Next Step

Po akceptacji briefu przygotowac architecture spec + ADR:

- source-of-truth model;
- lifecycle state machine;
- decisions capture/rotation/read policy;
- closeout validation contract;
- live work-index/status contract;
- milestone plan malych fixow zamiast jednego duzego patcha.
