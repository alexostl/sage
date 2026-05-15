---
title: "Plan: lifecycle, decisions i bookkeeping bez token bloat"
cycle_id: "20260514-doc-lifecycle-bookkeeping-architecture"
workflow: architect
phase: plan
status: completed
created: 2026-05-14
updated: 2026-05-14
approved_at: "2026-05-14"
approved_by: "alexostl"
related:
  - ".sage/work/20260514-doc-lifecycle-bookkeeping-architecture/spec.md"
  - ".sage/docs/decision-doc-lifecycle-bookkeeping.md"
  - ".sage/work/20260514-completed-cycle-bookkeeping-reconciliation-fix/manifest.md"
---

# Plan: lifecycle, decisions i bookkeeping bez token bloat

## Cel planu

Wdrozyc zaakceptowana architekture malymi milestone'ami, bez jednego wielkiego
patcha i bez tworzenia nowych warstw bloatu.

Plan ma cztery milestone'y plus finalna weryfikacje. Kazdy milestone powinien byc
testowalny niezaleznie, ale final confidence check obejmuje pelny RealHarness.

## Milestone 1 - Decisions policy i retention

### Zakres

Podzielic implementacje na trzy male podkroki, z osobna weryfikacja po kazdym:

1. **Capture policy surfaces**
   - Zmienic Rule 7 / process wording tak, zeby `decisions.md` byl decision
     logiem, nie process logiem.
   - Zrobic inventory i replacement surfaces:
     - constitution / generated instruction wording;
     - build/fix/architect/analyze checkpoint wording;
     - auto-review / auto-QA wording;
     - harness Signal 8 i powiazane tests.
2. **Retention i archive rotation**
   - Wdrozyc retention: 50 newest decisions w `.sage/decisions.md`, reszta w
     `.sage/decisions-archive.md`.
   - Archive ma byc newest-first, jesli potwierdzi sie, ze implementacja jest
     tylko lekko trudniejsza od append-only.
   - Archive rotation ma jeden legalny writer path: primary checkout.
   - Linked Git worktrees nie rotuja archive; overflow ponad 50 wpisow w
     worktree jest legalny.
   - Detection jest mechaniczna: primary checkout iff
     `git rev-parse --path-format=absolute --git-dir` equals
     `git rev-parse --path-format=absolute --git-common-dir`; linked worktree
     iff te sciezki sa rozne.
3. **Archive read policy**
   - Agent czyta `.sage/decisions-archive.md` search-first: `rg`, potem maly
     fragment wokol trafienia.
   - Full archive read wymaga nazwanego powodu: `rg` nic nie znalazl, trafienia
     nie daja potrzebnego kontekstu, potrzebny jest pelny audyt, archive moze
     byc uszkodzony, user prosi o pelny audyt albo trwa migracja/naprawa
     archive.

### Done criteria

- Workflowy nie nakazuja global decision entry dla auto-review verdict,
  intermediate checkpointow, completion checkpoint przed approval ani pure
  bookkeeping.
- Harness/testy nie wymagaja `.sage/decisions.md` update przy kazdym
  frontmatter/process state flip.
- Deterministic tests pokrywaja:
  - decision-worthy event -> decision entry wymagany;
  - process/bookkeeping event -> decision entry niewymagany;
  - rotation current 50 + archive;
  - no archive rotation in linked worktree.
- Test albo fixture dokumentacyjny pokrywa archive read policy: search-first i
  full-read only with named reason.
- Po podkrokach 1-3 przechodza zmienione deterministic suites.

### Ryzyka

- Zbyt ostra policy moze ukryc wazny audit.
- Zbyt szeroka policy zostawi obecny bloat.
- Archive newest-first moze byc bardziej konfliktogenne, jesli zostanie zle
  zaimplementowane.

## Milestone 2 - Closeout lifecycle i reconciliation

### Related intake absorbed

Milestone 2 obejmuje intake
`20260514-completed-cycle-bookkeeping-reconciliation-fix`, bo jest konkretnym
przypadkiem tej samej architektury: completed-cycle artifacts sa immutable, ale
ma istniec waski, mechanicznie walidowany path dla bookkeeping-only
reconciliation bez manualnego reopen i bez follow-up cycle.

### Zakres

- Doprecyzowac closeout validation jako structural checks, nie kruche grep po
  prozie.
- Wprowadzic completed-cycle bookkeeping reconciliation path:
  - bez follow-up cycle;
  - bez `decisions.md` entry;
  - bez dodatkowego audit logu dla oczywistych, pure bookkeeping patches.
- Wykorzystac candidate scope z intake'u
  `20260514-completed-cycle-bookkeeping-reconciliation-fix` jako punkt startowy
  implementacji:
  - krotka constitution rule po angielsku;
  - maly PreToolUse helper/allowlist dla completed `manifest.md`
    bookkeeping-only patches;
  - regresje Bats dla allow/block cases.
  Candidate scope z intake'u trzeba przy tym zawezic: reconciliation nie
  dotyka `.sage/decisions.md`; decision log migration/retention to osobny
  temat z Milestone 1.
- Opisac i wdrozyc reopen boundary:
  - reopen tylko natychmiastowo w tej samej aktywnej rozmowie;
  - pozniejszy merytoryczny blad -> follow-up cycle;
  - pozniejszy pure bookkeeping -> reconciliation.
- Utrzymac bogate manifest body, ale wymagac spojnosci `## State` z
  frontmatter.

### Done criteria

- Closeout nie zostawia `status: completed` z aktywnym `phase`, stale active
  `Next step` albo nieoznaczonym folded sibling intake.
- Bookkeeping reconciliation completed cycle nie tworzy global decision entry
  ani osobnego audit logu, jesli patch jest jednoznacznie pure bookkeeping.
- Intake `20260514-completed-cycle-bookkeeping-reconciliation-fix` jest
  domkniety albo jednoznacznie oznaczony jako folded into ten milestone po
  implementacji.
- Tests pokrywaja legalne bookkeeping reconciliation i blokady dla zmian
  historycznych faktow.
- Po milestone przechodza zmienione deterministic suites.

### Ryzyka

- Bez hooka czesc ochrony zalezy od workflow/tooling discipline.
- Phrase scan moze wrocic jako twardy grep, jesli implementation nie rozdzieli
  structural checks od advisory stale wording.

## Milestone 3 - Live work-index / status formalization

### Zakres

- Sformalizowac `work_index` jako manifest-derived subset obecnego
  `sage status --json`.
- Rozdzielic composite status output na warstwy:
  - `work_index` / `cycles`;
  - `recent_decisions`;
  - `health`.
- Utrzymac kompatybilnosc istniejacego `sage status --json`, ale nazwac stabilny
  kontrakt warstwy lifecycle:
  - `work_index.cycles[]` albo rownowazne `cycles[]`;
  - pola cyklu: `cycle_id`, `title`, `workflow`, `status`, `phase`, `priority`,
    `owner`, `updated`, `resolution`, `folded_into`, `active_session_id`;
  - `work_index.counts` dla status/resolution counts;
  - `recent_decisions[]` i `health` sa context/diagnostic, nie source-of-truth
    dla lifecycle.
- Upewnic sie, ze `work_index` nie czyta pelnych artefaktow, raw evidence ani
  transcriptow.
- Nie wprowadzac persistent cache na start.

### Done criteria

- `sage status --json` albo rownowazny output ma jasna granice warstw.
- Tests potwierdzaja, ze work-index layer jest manifest-level i nie zalezy od
  body archive, raw harness evidence ani doctor-like health.
- Tests potwierdzaja kompatybilnosc JSON shape albo jawnie dokumentuja
  backwards-compatible aliasy.
- Session-start/status pozostaja lekkie.
- Po milestone przechodza zmienione deterministic suites.

### Ryzyka

- Jesli status UI nadal miesza state, decisions i health bez nazwania warstw,
  przyszli agenci moga ponownie uznac decisions/health za source-of-truth dla
  lifecycle.

## Milestone 4 - One-time migration dla Sage SelfHost i alex-os-dev

### Zakres

To nie jest nowy mechanizm frameworka, migrator ani komenda. To jednorazowa
migracja realnych repo Alexa z zachowaniem target repo ownership:

- `/Users/alexostl/Developer/sage-selfhost`
- `/Users/alexostl/Developer/alex-os-dev`

Cel: doprowadzic realne repo Alexa do nowego kontraktu po wdrozeniu Milestone
1-3, bez projektowania uniwersalnego upgrade path dla wszystkich starych
projektow Sage.

`plan-milestone-4.md` jest superseding authority dla szczegolowego zakresu
Milestone 4. Ten cykl moze mutowac tylko `sage-selfhost`. Dla `alex-os-dev`
ten cykl przygotowuje read-only inventory i handoff/checklist; wlasciwa
migracja `alex-os-dev` musi odbyc sie w osobnej sesji z cwd/target repo
`/Users/alexostl/Developer/alex-os-dev`.

Zakres operacyjny:

- W `sage-selfhost`: uruchomic albo odtworzyc efekt istniejacego update path
  tam, gdzie dotyczy generated `AGENTS.md`, Codex hooks/runtime surfaces i
  tests.
- W `alex-os-dev`: bez write operations z tego cyklu; przygotowac handoff dla
  osobnej target-repo sesji.
- Sprawdzic read-only, czy `AGENTS.md` w obu repo ma albo powinien miec
  aktualny managed prefix:
  decision log policy, archive read policy, worktree archive rule,
  work-index/status lifecycle wording i closeout/reconciliation wording.
- Sprawdzic, czy user territory pod `SAGE-MANAGED-END` zostal zachowany.
- Sprawdzic, czy `sage-selfhost` ma nowy hook path dla decisions retention, ale
  bez wymuszania recznej rotacji w linked worktree.
- Dla `sage-selfhost`: zweryfikowac aktualny `.sage/decisions.md` i
  `.sage/decisions-archive.md` po lazy rotation; nie robic masowego rewrite
  historii, jesli rotacja zachowala audytowalnosc.
- Dla `alex-os-dev`: zapisac self-contained handoff: expected contracts,
  read-only inventory results, checklist startowa, stop conditions i zakaz
  edycji installed `~/.codex/*` / `~/.claude/*` poza source-of-truth.
- Zrobic targeted status check w `sage-selfhost`; `alex-os-dev` tylko read-only
  sanity bez mutacji.

### Done criteria

- `sage-selfhost` ma aktualne generated Codex instruction/runtime surfaces
  wymagane przez Milestone 1-3 albo jawnie opisany residual risk.
- `sage-selfhost` ma bounded current decisions albo jawnie opisany residual risk,
  jesli lazy rotation zostaje odlozona do kolejnego legalnego write path.
- `alex-os-dev` ma self-contained handoff do osobnej sesji target-repo, bez
  write operations z tego cyklu.
- Nie powstaje nowa komenda, helper migracyjny ani persistent migration
  framework.
- Wynik jest opisany w closeout tego cyklu jako `sage-selfhost` migration/check
  plus `alex-os-dev` handoff.

### Ryzyka

- `alex-os-dev` moze miec wlasne globalne source-of-truth dla Codex/Claude
  config; ten cykl nie moze mutowac tego repo.
- Jesli `sage update` w `sage-selfhost` dotknie user territory albo unmanaged
  config, trzeba zatrzymac sie i pokazac diff zamiast "naprawiac" na sile.
- Rownolegle worktrees moga miec stary `AGENTS.md` do czasu merge/update; to
  akceptowalne, jesli primary repo jest poprawnie zmigrowane.

## Final verification

Po milestone'ach:

- po kazdym milestone uruchomic zmienione deterministic suites;
- uruchomic pelny RealHarness, nie tylko targeted subset;
- zestawic wynik RealHarness z testami deterministic;
- jesli RealHarness pass semantics nadal ma znane ograniczenia, opisac residual
  risk zamiast traktowac green jako absolutna czystosc.
- wykonac one-time migration/check dla `sage-selfhost` oraz read-only handoff
  sanity dla `alex-os-dev`, bez budowania ogolnego migration framework.

## Rollback

- Wording policy mozna cofnac przez revert workflow/generator/test changes.
- Decisions archive migration musi zachowac calosc historii, wiec rollback
  polega na scaleniu archive z current albo odtworzeniu z Git.
- Work-index formalization nie dodaje persistent cache, wiec rollback powinien
  byc niski.

## Open implementation questions

- Czy archive newest-first jest rzeczywiscie tylko lekko trudniejsze od
  append-only.
- Czy closeout validation bedzie helperem shell/Python, czy zostanie w
  workflow + tests.
