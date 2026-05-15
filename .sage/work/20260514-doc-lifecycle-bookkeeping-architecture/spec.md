---
title: "Spec: lifecycle, decisions i bookkeeping bez token bloat"
cycle_id: "20260514-doc-lifecycle-bookkeeping-architecture"
workflow: architect
phase: design
status: completed
created: 2026-05-14
updated: 2026-05-14
approved_at: "2026-05-14"
approved_by: "alexostl"
handoff: |
  Key decisions: Manifest pozostaje source-of-truth dla lifecycle state;
    `decisions.md` ma byc decision logiem, nie process logiem; live
    `sage status --json` formalizujemy jako work-index bez nowego recznie
    edytowanego pliku; decisions retention to 50 current + jeden
    `.sage/decisions-archive.md`; linked worktrees nie rotuja archive;
    bookkeeping reconciliation nie wymaga follow-up cycle; reopen tylko jako
    natychmiastowa korekta w tej samej aktywnej rozmowie.
  Open questions: Czy archive newest-first bedzie implementacyjnie tylko lekko
    trudniejsze od append-only; czy closeout validation potrzebuje helpera czy
    wystarczy workflow + tests.
  Risks: Decisions capture policy moze byc za ostra i zgubic wazny audit albo
    za szeroka i zostawic bloat. Rotation logic moze produkowac konflikty w
    worktrees, jesli no-archive-rotation nie bedzie dobrze egzekwowane.
  Next agent should: Review spec + ADR pod katem minimalizmu, audytowalnosci,
    worktree merge behavior i ryzyka stworzenia nowego bloatu.
related:
  - ".sage/work/20260514-doc-lifecycle-bookkeeping-architecture/brief.md"
  - ".sage/docs/decision-doc-lifecycle-bookkeeping.md"
---

# Spec: lifecycle, decisions i bookkeeping bez token bloat

## 1. Cel systemu

Sage ma rozdzielic trzy rzeczy, ktore zaczely sie mieszac:

- **state** - co jest aktywne, co jest intake, co jest completed;
- **decision audit** - dlaczego podjeto wazna decyzje;
- **process evidence** - jak doszlismy do decyzji, jakie byly review,
  checkpointy, testy i logi.

Najwazniejszy cel: agent ma odpowiedziec na zwykle pytanie o status bez
czytania calej `.sage/work`, calego `.sage/decisions.md`, raw harness evidence
albo transcriptow.

## 2. Source-of-truth model

### Manifest

`manifest.md` jest source-of-truth dla lifecycle state:

- `cycle_id`
- `workflow`
- `status`
- `phase`
- `scope`
- `resolution`
- `folded_into`
- `closed_at`
- `source_commits`

Body manifestu zostaje bogate. To nie jest bloat sam w sobie, bo manifest jest
najlepszym miejscem na ludzki opis problemu. Problemem jest niespojnosc body z
frontmatter.

### Decisions

`.sage/decisions.md` jest audit trail realnych decyzji. Nie jest:

- status database;
- process logiem;
- pelnym transcript chainem;
- miejscem na kazdy auto-review verdict.

### Work-index

Work-index to live, lekki widok z manifestow. Na start oznacza formalizacje
manifestowej czesci istniejacego `sage status --json`, nie nowy plik.

`sage status --json` moze pozostac composite output, ale musi miec jawne
warstwy:

- `work_index` / `cycles` - manifest-derived state;
- `recent_decisions` - ostatnie naglowki decyzji, nie state source;
- `health` - osobny operational health summary, nie czesc work-index.

Kontrakt:

- czyta manifest frontmatter i ewentualnie waskie state fields;
- nie czyta pelnych `spec.md`, `plan.md`, `root-cause.md`, `qa-report.md`;
- nie czyta `harness-run-*`, raw `.jsonl`, `.stderr`, target snapshots;
- nie traktuje `recent_decisions` ani `health` jako zrodla prawdy dla
  lifecycle state;
- nie zapisuje persistent cache na start.

## 3. Lifecycle model

### Active states

- `intake` - captured work, bez aktywnej implementacji;
- `in-progress` - aktywny cykl lub checkpoint gate;
- `paused` - zaparkowany cykl, jawnie resumable.

### Completion states

- `completed` - cykl zamkniety i audytowalny;
- `completed` + `resolution: folded_into` - cykl merytorycznie zamkniety przez
  inny anchor cycle;
- `completed` + `resolution: superseded` - cykl historycznie zastapiony.

Nie rekomendujemy osobnego `status: folded_into`, bo uproszczenie status count
jest wazniejsze. Semantyka folding idzie do `resolution` i `folded_into`.

### Reopen

`reopen` nie jest normalna sciezka pracy. Jest wyjatkiem dla natychmiastowej
korekty w tej samej aktywnej rozmowie.

Jesli blad zostaje wykryty pozniej:

- pure bookkeeping -> bookkeeping reconciliation;
- merytoryczny blad fixa -> follow-up cycle.

## 4. Completed-cycle bookkeeping reconciliation

Bookkeeping reconciliation porzadkuje zapis, nie zmienia historii.

Legalne bez follow-up cycle:

- stale `Next step`;
- `phase` niespojny ze `status`;
- brak `closed_at`;
- brak `resolution` / `folded_into`;
- manifest body opisuje stary gate mimo completed frontmatter.

Nielegalne jako bookkeeping:

- zmiana scope;
- zmiana approval meaning;
- zmiana verification evidence;
- dopisanie nowego findingu jako zamknietego historycznie;
- zmiana wyniku implementacji;
- reinterpretacja, czy fix byl poprawny.

Bookkeeping-only reconciliation nie wymaga decyzji w `.sage/decisions.md` i
nie wymaga osobnego audit logu. To ma byc waska korekta zapisu, nie kolejne
zrodlo bloatu. Jesli patch nie jest jednoznacznie pure bookkeeping albo dotyka
faktow historycznych, nie korzysta z tego wyjatku i musi przejsc normalny
workflow.

## 5. Decisions capture policy

### Trafia do decisions

- finalnie zaakceptowany root cause;
- finalnie zaakceptowany plan/scope;
- scope expansion;
- final closeout;
- trwala zasada projektowa;
- decyzja uzytkownika zmieniajaca kierunek, priorytet, ownership albo ryzyko.

### Nie trafia do decisions

- auto-review verdict jako osobny wpis;
- `needs revision` jako osobny wpis;
- intermediate checkpoint przed akceptacja;
- kazda rewizja root cause/planu;
- completion checkpoint przed final approval;
- pure bookkeeping reconciliation;
- raw verification output, jesli istnieje w artefakcie cyklu.

Te informacje powinny trafic do najblizszego wlasciwego artefaktu:
`manifest.md`, `root-cause.md`, `plan.md`, `qa-report.md`, `verification.md`
albo logu.

### Compatibility surfaces to replace

Ta polityka musi zastapic stare compliance surfaces, ktore dzisiaj wymagaja
decision entry przy zbyt wielu zdarzeniach. Milestone 1 nie moze tylko zmienic
prozy w workflowach; musi zrobic inventory i aktualizacje:

- Rule 7 wording w constitution / generated instructions;
- workflow checkpoint wording dla build/fix/architect/analyze;
- auto-review / auto-QA wording, jesli nakazuje global decision entry;
- harness Signal 8 i testy, ktore dzisiaj lacza frontmatter flips z
  obowiazkowym `.sage/decisions.md` update.

Docelowa zasada: frontmatter flip wymaga decisions entry tylko wtedy, gdy
zdarzenie jest decision-worthy wedlug tej polityki. Pure bookkeeping/process
state nie wymaga global decision entry.

## 6. Decisions retention policy

### Current decisions

`.sage/decisions.md` trzyma 50 najnowszych decyzji.

### Archive

Starsze decyzje trafiaja do `.sage/decisions-archive.md`.

Archive powinien byc newest-first, jesli implementacja jest tylko troche
trudniejsza od append-only. Na poziomie architektury preferujemy newest-first,
bo current i archive maja wtedy spojna logike.

### Worktree rule

Linked Git worktree nie rotuje archive.

W worktree overflow ponad 50 decyzji w `.sage/decisions.md` jest legalny i
tymczasowy. Archive mutation jest wylaczona, zeby nie produkowac konfliktow
merge w wielu rownoleglych worktrees.

Detection contract powinien byc mechaniczny i tani. Plan implementacji ma
zweryfikowac dokladna komende, ale kierunek jest:

- primary checkout moze rotowac archive;
- linked worktree nie rotuje archive;
- tooling odroznia je przez Git metadata, np. relacje `git rev-parse --git-dir`
  i `git rev-parse --git-common-dir`;
- archive rotation ma jeden legalny writer path: decision write albo closeout w
  primary checkout, nie rownolegle worktrees.

### Archive read policy

Archive jest search-first:

1. `rg` po cycle id, batch name, dacie, tytule albo slowach kluczowych.
2. Odczyt malego fragmentu wokol trafienia.
3. Kolejne celowane `rg`, jesli potrzebne.

Full archive read tylko z nazwanym powodem:

- `rg` nic nie znajduje, a historyczny kontekst jest konieczny;
- `rg` znajduje trafienia, ale nie daje potrzebnego kontekstu;
- potrzebny jest pelny audyt;
- archive moze byc uszkodzony;
- user jawnie prosi o pelny audyt;
- agent wykonuje migracje albo naprawe archive.

## 7. Closeout validation

Closeout path jest primary UX dla consistency.

Przed `status: completed` trzeba potwierdzic structural checks:

- `phase: completed`;
- `## State` albo rownowazne state fields nie zawieraja aktywnego next step;
- sibling/folded intakes maja `resolution` i `folded_into`;
- decisions entry powstaje tylko, jesli closeout jest decision-worthy wedlug
  capture policy.

Phrase scan po prozie moze byc tylko advisory. Frazy typu
`completion-checkpoint`, `verify`, `commit and push pending` moga pomoc wykryc
stale wording, ale nie sa samodzielnym source-of-truth i nie powinny blokowac
legalnego closeoutu bez strukturalnego potwierdzenia niespojnosci.

Na start bez hooka. Hook moze byc pozniejszym malym guardrailem, jesli sama
walidacja workflow nie wystarczy.

## 8. Migration strategy

Architektura nie wymaga natychmiastowej duzej migracji wszystkiego.

Minimalna migracja:

1. Przestac dopisywac mikrodecyzje wedlug nowej capture policy.
2. Wprowadzic rotacje: current 50, archive one-file newest-first.
3. Zachowac caly historyczny audit w archive.
4. Nie tworzyc `summary.md`.
5. Nie migrowac raw evidence/logow.

## 9. Verification strategy

Na koniec implementacji tej architektury uruchomic pelny RealHarness, nie tylko
targeted subset. Targeted RealHarness pozostaje przyszlym usprawnieniem dla
tanszych punktowych regresji, ale ten cykl ma dostac pelny run jako final
confidence check.

Pelny RealHarness nie zastepuje Bats/unit regression tests dla konkretnych
zmian. Traktujemy go jako koncowa weryfikacje real-agent behavior po
milestone'ach.

## 10. Milestone sketch

Milestone 1 - Decisions policy i rotation:

- zrobic inventory i replacement starych compliance surfaces: Rule 7,
  workflow checkpoint wording, auto-review/auto-QA wording, harness Signal 8 i
  testy;
- zmienic workflow wording, zeby nie logowal auto-review/process events jako
  global decisions;
- dodac rotacje current 50 + archive;
- respektowac no-archive-rotation in linked worktrees.

Milestone 2 - Closeout lifecycle consistency:

- doprecyzowac closeout checklist;
- dodac bookkeeping reconciliation path;
- opisac reopen/follow-up boundaries.

Milestone 3 - Live status/work-index formalization:

- nazwac `work_index` jako manifest-derived subset, oddzielony od
  `recent_decisions` i `health`;
- upewnic sie, ze warstwa `work_index` czyta tylko manifest-level state;
- nie wprowadzac persistent cache na start.

Final verification:

- uruchomic pelny RealHarness po implementacji milestone'ow;
- wynik RealHarness zestawic z Bats/testami deterministic;
- jesli RealHarness pass semantics nadal ma znane ograniczenia, opisac je jako
  residual risk zamiast udawac, ze green oznacza pelna czystosc.

## 11. Open review points

- Czy archive newest-first jest wystarczajaco proste w implementacji.
- Czy 50 decisions zostaje stale, czy future tuning bedzie potrzebny po
  ograniczeniu mikrodecyzji.
- Czy closeout validation potrzebuje helpera, czy wystarczy workflow + tests.
