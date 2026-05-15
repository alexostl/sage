---
cycle_id: "20260514-source-mutating-cycle-concurrency-fix"
title: "Fix: source-mutating cycles nie mogą działać równolegle w jednym repo"
workflow: fix
phase: intake
status: intake
created: 2026-05-14
updated: 2026-05-14
owner: alexostl
priority: P1
needs-triage: true
source: "conversation"
related:
  - "20260509-alex-readable-change-explanations-fix"
  - "20260514-doc-lifecycle-bookkeeping-architecture"
  - "runtime/platforms/codex/hooks/lib/active_init.sh"
  - "runtime/platforms/codex/hooks/pre-tool-validate.sh"
---

# Fix: source-mutating cycles nie mogą działać równolegle w jednym repo

## State

**Current phase:** intake - capture only. Implementacja nie została rozpoczęta.

**Next step:** Uruchomić `/sage:fix`, zdiagnozować model współbieżności cykli i
zdecydować, czy blokada ma być per repo, per branch, czy per worktree.

## Problem

W jednym repo mogą być równolegle `in-progress` cykle, które realnie chcą
dotykać kodu źródłowego. W praktyce prowadzi to do konfliktu ownership: hook
wybiera jeden aktywny cykl jako właściciela mutacji, a agent próbujący pracować
nad drugim cyklem dostaje blok poza scope. To nie jest tylko problem UX hooka;
to oznacza, że dwa cykle mogą jednocześnie rościć sobie prawo do source edits w
tym samym workspace.

Przykład z 2026-05-14:

- `20260509-alex-readable-change-explanations-fix` jest `fix/deliver` i ma
  zaakceptowany scope na source/test/instruction edits.
- `20260514-doc-lifecycle-bookkeeping-architecture` jest `architect/design` i
  także `status: in-progress`.
- Próba rozpoczęcia implementacji Batcha 7 została zablokowana, bo hook wybrał
  nowszy aktywny cykl architektoniczny jako właściciela patcha.

## Desired behavior

Sage powinien mieć prostą regułę:

**Cykle mogą współistnieć równolegle, dopóki nie zmieniają kodu źródłowego.**

Konsekwencje:

- `.sage` artifacts, raporty, briefy, specy, ADRy, review, analiza i QA report
  mogą być równolegle otwarte.
- Pierwszy cykl, który chce zmieniać source/runtime/test/instruction files,
  staje się właścicielem source mutation w danym workspace.
- Dopóki ten cykl nie zostanie zaparkowany, zamknięty albo jawnie
  handoffowany, drugi cykl nie może równolegle zmieniać source files.
- Nazwa workflow nie jest najważniejsza. `architect` może działać równolegle,
  dopóki robi brief/spec/ADR/plan. Gdy zaczyna milestone implementation,
  obowiązuje go ta sama blokada co `fix`/`build`.
- `QA` może działać równolegle, dopóki zapisuje raport/evidence. Jeśli zaczyna
  zmieniać testy, fixtures albo kod, musi wejść w source-mutating ownership
  albo przekazać pracę do `/fix`.

## Open questions

- Czy blokada ma obowiązywać per repo, per branch, czy per worktree?
- Jak technicznie nazwać granicę workspace ownership: repo, branch, worktree
  albo kombinacja tych pojęć?
- Jak hook ma rozpoznawać `source-mutating` cycle: po `workflow`, `phase`,
  `scope`, explicit frontmatter field, czy kombinacji?
- Czy istniejące równoległe `.sage/**` conceptual cycles mają zostać dozwolone
  bez parkowania?
- Jak komunikat recovery ma brzmieć, żeby agent parkował/wznawiał właściwy
  cykl zamiast amputować scope?

## Candidate scope

- Zdefiniować taxonomy `source-mutating` vs `conceptual/report-only`.
- Dopisać prostą zasadę: równoległe cykle są legalne, dopóki nie mutują
  source/runtime/test/instruction files.
- Doprecyzować Operating Kernel / workflow guidance dla równoległych cykli.
- Zmienić hook resolver tak, żeby nie wybierał losowo/najnowszego aktywnego
  cyklu, jeśli source-mutating ownership jest konfliktowe.
- Dodać regresje dla scenariusza: aktywny conceptual architect cycle nie
  blokuje zaakceptowanego source-mutating fix cycle albo wymaga jawnego
  park/handoff zamiast błędnego scope ownera.

## Boundary

Ten intake nie zmienia jeszcze hooków ani zasad runtime. Nie rozstrzyga też
ostatecznie, czy granica ma być per repo, per branch, czy per worktree.
