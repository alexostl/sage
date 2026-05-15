---
cycle_id: "20260515-codex-hook-policy-consolidation"
title: "Plan: Milestone 0 Discovery Spike"
workflow: architect
phase: discovery-spike-plan
status: approved
created: 2026-05-15
updated: 2026-05-15
owner: alexostl
source: "brief checkpoint revision"
approved_by: alexostl
approved_at: "2026-05-15"
related:
  - ".sage/work/20260515-codex-hook-policy-consolidation/brief.md"
  - "runtime/platforms/codex/hooks/pre-tool-validate.sh"
  - "runtime/platforms/codex/harness/run-harness.sh"
---

# Plan: Milestone 0 Discovery Spike

## Cel

Zanim zaprojektujemy docelową architekturę hooków, potrzebujemy danych
porównawczych. Discovery Spike ma odpowiedzieć na pytanie:

**Które zachowania powinny być twardym enforcementem, które audit-only /
recovery, a które wystarczy zostawić instrukcjom agenta?**

## Hipoteza

Najcenniejszy nie będzie zwykły tryb `hooks off`, tylko porównanie trzech
wariantów:

1. **hooks-on** - obecne zachowanie produkcyjne.
2. **hooks-off** - naturalne zachowanie agenta bez enforcementu.
3. **audit-only** - hook analizuje i loguje `would_block`, ale nie blokuje.

Audit-only prawdopodobnie da najlepsze dane, bo pokazuje false positives i true
positives bez przerywania pracy.

## Scenariusze wejściowe

Minimalny zestaw powinien pochodzić z realnych incydentów, najlepiej z
konkretnych thread traces, a nie z promptów pisanych pod test. RealHarness jest
dobrym kandydatem, ale tylko jeśli scenariusze zachowują naturalny kształt
zadań, które faktycznie wykonywali agenci.

1. Same-turn approval po zaakceptowanym planie.
2. Cross-repo `.sage/work` capture z repo A do repo B.
3. Surgical wording change w skillu/instruction surface.
4. Single config / repo hygiene change.
5. Completed-cycle bookkeeping reconciliation.
6. Memory/self-learning correction i delete/update flow.
7. Source mutation poza scope.
8. Multi-cycle `.sage/work` mutation.

Nie trzeba od razu odpalać całego RealHarness. Spike powinien dobrać mały,
czytelny zestaw 6-10 scenariuszy, które dobrze różnicują politykę hooków.

### Źródła scenariuszy

Pierwszy krok spike'a to ekstrakcja realistycznych promptów z wątków:

- `codex://threads/019e2874-24cc-72f3-b333-31d9a213ab7c` - memory/self-learning
  correction, scope mismatch i read-only-ish `sqlite3` zablokowany przez Bash
  guard.
- `codex://threads/019e095f-5328-7e40-a288-0a524d6e0d0d` - local MCP secret
  override, microfix vs Moderate+ oraz cross-repo intake capture.
- `codex://threads/019e25b2-3a20-7ad3-ac90-bf4ded52b907` oraz powiązany
  archived trace z frazą `ok, poza repo ma byc jednoznacznie legalne...` -
  outside-repo Bash writes, gitignored local artifacts i managed surfaces.
- Existing RealHarness scenarios `03-build-out-of-scope`, `04-fix-trigger`,
  `08-safe-autofix-metadata` i `11-bug-report-no-fix` jako historical controls,
  ale tylko po sprawdzeniu, czy nadal reprezentują realny problem.

Każdy scenariusz powinien mieć:

- oryginalny thread source;
- naturalny user prompt albo minimalnie zanonimizowaną wersję;
- expected behavior po ludzku;
- expected hook/audit behavior;
- klasyfikację ryzyka: source/config/docs/memory/cross-repo.

## Tryby uruchomienia

RealHarness powinien być preferowanym runnerem, jeśli da się go uruchomić na
wybranym subsetcie scenariuszy i przełączyć tryb hooków bez dużej przebudowy.
Jeśli obecny RealHarness nie wspiera subsetów albo hook mode, Milestone 0 ma
najpierw sprawdzić, czy mały wrapper będzie tańszy niż ręczne target worktrees.

### hooks-on

Użyć obecnego runtime hooków. Celem jest potwierdzić aktualne bloki i recovery.

### hooks-off

Uruchomić w bezpiecznym target repo albo worktree, nie w normalnym selfhost
workflow. Po runie zebrać:

- transcript;
- final git diff;
- `.sage` state;
- czy agent sam zachował workflow gates;
- czy powstały nieautoryzowane source/config/instruction mutations.

### audit-only

Preferowany spike target. Hook powinien wykonać tę samą analizę co dziś, ale
zamiast blokować zapisać event:

```json
{
  "kind": "would_block",
  "reason_code": "...",
  "tool": "...",
  "paths": ["..."],
  "cycle_id": "...",
  "target_repo": "...",
  "message_code": "..."
}
```

Spike ma rozstrzygnąć, czy audit-only da się zrobić tanio jako tymczasowy
harness/worktree mode, bez przebudowy całej architektury.

## Metryki

Dla każdego scenariusza porównać:

- czy zadanie zostało wykonane;
- czy hook blokował albo `would_block`;
- czy blok był true positive, false positive, albo expected-but-bad-UX;
- ile recovery kroków wymagał agent;
- czy agent amputował scope;
- czy agent obszedł hook inną warstwą, np. memory/wiki;
- czy finalny repo state jest zgodny z oczekiwanym workflow.

## Stop Conditions

- Jeśli audit-only wymaga dużej przebudowy hooków, zatrzymać się i wrócić do
  designu z wnioskiem, że Milestone 0 musi użyć prostszego hooks-off baseline.
- Jeśli hooks-off miałby działać na prawdziwym selfhost repo zamiast izolowanego
  target/worktree, zatrzymać się.
- Jeśli scenariusze zaczynają wymagać nowej polityki zamiast pomiaru, zatrzymać
  spike i zapisać pytanie do `spec.md`.

## Deliverables

- Krótki report w tym cyklu: `discovery-spike-report.md`.
- Plik scenariuszy albo patch do istniejącego RealHarness tylko wtedy, gdy jest
  to najtańszy sposób uruchomienia spike'a.
- Tabela scenariuszy z trzema trybami i verdictami.
- Lista decyzji, które muszą wejść do `spec.md`.
- Rekomendacja, które open intake'y foldować do planu architektonicznego.

## Checkpoint

Plan zatwierdzony przez Alexa. Następny krok to zaprojektowanie najtańszego
sposobu uruchomienia spike'a: istniejący harness, tymczasowy wrapper, czy
ręcznie kontrolowane target worktrees.
