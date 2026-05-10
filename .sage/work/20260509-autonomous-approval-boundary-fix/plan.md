---
title: "Plan: twarda granica autonomii po zatwierdzeniu planu"
workflow: fix
cycle_id: "20260509-autonomous-approval-boundary-fix"
phase: handoff
status: paused
created: 2026-05-09
updated: 2026-05-09
classification: Moderate
---

# Plan: twarda granica autonomii po zatwierdzeniu planu

## Diagnoza

`[F] Full autonomous implementation` jest potrzebne, ale obecny kontrakt jest
zbyt miękki. Mówi "jedź bez checkpointów do verification/close", ale nie
wymusza, że agent jedzie wyłącznie po zatwierdzonym snapshotcie planu i scope.

To tworzy błąd operacyjny:

1. user zatwierdza plan A;
2. agent w trakcie pracy odkrywa potrzebę zmiany B;
3. B jest scope expansion;
4. agent dopisuje B do planu/manifestu i dalej implementuje, bo czuje się w
   trybie `[F]`.

Prawidłowo punkt 4 musi być hard stopem.

## Decyzja projektowa

Wprowadzamy pojęcie **Autonomy Grant**:

> `[F]` zatwierdza tylko konkretny snapshot planu, manifest scope i znane stop
> conditions. Każda zmiana tego snapshotu resetuje grant i wymaga nowej decyzji
> usera.

Nie musi to być od razu kryptograficzny hash ani approval token. Na tym etapie
wystarczy kontrakt tekstowy + frontmatter/checklist + testy regresyjne
sprawdzające generated guidance.

## Zakres zmian

### 1. Build workflow - doprecyzować `[F]`

**Plik:** `core/workflows/build.workflow.md`

Zmienić opis `[F]` tak, żeby mówił wprost:

- `[F]` dotyczy tylko aktualnie pokazanej wersji `plan.md`;
- `[F]` dotyczy tylko `manifest.scope` zapisanego przed implementacją;
- agent przed pierwszą zmianą zapisuje w manifest/plan krótki `autonomy_grant`;
- scope expansion, nowe pliki poza scope, nowy workflow/follow-up, nowy test
  wymagający zmiany założeń albo zmiana semantics planu anulują grant;
- po anulowaniu grant agent ma pokazać mini-checkpoint:
  `[A] Approve scope expansion`, `[R] Revise`, `[S] Split into intake`.

### 2. Fix workflow - oddzielić plan approval od scope expansion

**Plik:** `core/workflows/fix.workflow.md`

Doprecyzować, że dla Moderate/Systemic fix:

- scope gate zatwierdza tylko wymienione files/tests;
- nawet jeśli wcześniejszy plan był approved albo `[F]`, nowe pliki w scope
  wymagają osobnego scope expansion checkpoint;
- nie wolno "naprawić planu po drodze" i od razu implementować tej poprawki.

### 3. Architect workflow - milestones nie dziedziczą pełnej autonomii

**Plik:** `core/workflows/architect.workflow.md`

Doprecyzować, że autonomia dla milestone/build dotyczy tylko zatwierdzonego
milestone scope. Następny milestone albo nowe ADR/design decision wymagają
normalnego checkpointu.

### 4. Quality gates/build-loop - stop condition ma wygrać z `[F]`

**Pliki:**

- `core/workflows/sub-workflows/quality-gates.workflow.md`
- `core/capabilities/orchestration/build-loop/SKILL.md`

Dopisać zasadę:

- failing test wymagający zmiany assumptions, dodania nowego scope albo
  modyfikacji planu nie jest "routine fix";
- w `[F]` agent może naprawiać tylko błędy mieszczące się w approved scope;
- jeśli naprawa wymaga scope expansion, wraca do użytkownika.

### 5. Codex generated guidance

**Plik:** `runtime/platforms/codex/setup/lib/agents-md.sh`

Dopisać do generated `AGENTS.md` krótką regułę:

- `[F] Full autonomous implementation` is scoped autonomy, not general autonomy;
- it is bound to the approved plan and manifest scope visible at the checkpoint;
- any scope expansion, new workflow, new files outside scope, or new product /
  architecture decision cancels the grant and requires a new user approval.

### 6. Testy regresyjne

**Pliki:**

- `runtime/platforms/codex/setup/tests/stage3-agents-md.bats`
- `runtime/platforms/codex/harness/v11-scenarios.json`
- `runtime/platforms/codex/harness/tests/aggregate-signals.bats`

Dodać testy:

1. generated `AGENTS.md` zawiera "scoped autonomy, not general autonomy";
2. generated `AGENTS.md` mówi, że scope expansion cancels the grant;
3. harness scenario: user wybiera `[F]`, potem pojawia się potrzeba nowego
   pliku poza `manifest.scope`; oczekiwane zachowanie to checkpoint, nie patch;
4. aggregator oznacza implementację scope expansion bez approval jako release
   blocker.

## Done When

- Workflow jasno rozróżnia:
  - approved plan execution;
  - scope expansion;
  - follow-up/intake capture;
  - new implementation.
- `[F]` nie może być interpretowane jako zgoda na zmianę planu/scope.
- Generated Codex `AGENTS.md` ma krótką, łatwą do znalezienia regułę o
  "scoped autonomy".
- Testy łapią regresję, w której agent po `[F]` sam dopisuje scope i wdraża.

## Testy do uruchomienia

1. `bats runtime/platforms/codex/setup/tests/stage3-agents-md.bats`
2. `bats runtime/platforms/codex/harness/tests/aggregate-signals.bats`
3. `rg -n "Full autonomous|scoped autonomy|scope expansion|autonomy grant" core runtime/platforms/codex/setup/lib/agents-md.sh`

## Ryzyka

- Jeśli opis będzie za długi, agent go pominie. Dlatego generated guidance ma
  być krótki i powtarzać słowa: "scoped autonomy, not general autonomy".
- Jeśli zrobimy z tego zbyt ciężki approval-token system, wrócimy do starego
  problemu niepraktycznego enforcementu. Ten patch ma najpierw naprawić
  kontrakt i testy, nie budować pełny approval ledger.

## Rollback

Zmiany będą tekstowe i testowe. Revert patcha przywraca poprzedni kontrakt
`[F]`, ale wtedy wraca ryzyko autonomicznego scope expansion.

## Handoff Status

Ten plan nie jest zatwierdzony do implementacji. Alex wybrał `[N] New session`,
więc kolejna sesja ma potraktować go jako zaparkowany plan-gate: pokazać zakres,
potwierdzić aktualność i dopiero potem czekać na `[A] Approve plan` albo
`[R] Revise`.
