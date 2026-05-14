---
status: completed
created: 2026-05-14
updated: 2026-05-14
classification: Moderate
approved_by: alexostl
approved_at: 2026-05-14
---

# Fix Plan

## Classification

Moderate. Fix dotyka runtime hooka, testów hooka oraz minimalnych
workflow/guidance surfaces, żeby `[I] Revise and Implement in the same turn`
nie było tylko opisem rozmownym, ale miało jawny kontrakt.

## Marker Contract

Machine-checkable contract jest manifest-first i fail-closed:

```yaml
implementation_approval:
  mode: approved | conditional_revision
  approved_by: alexostl
  approved_at: "YYYY-MM-DD"
  gate: fix-scope-gate | plan-gate | milestone-plan-gate
  artifact: ".sage/work/<cycle>/plan.md"
  scope: manifest
  revision: "<required only for conditional_revision>"
```

Hook może potraktować same-turn `manifest.md` albo canonical `plan.md`
bookkeeping jako legalny tylko wtedy, gdy:

- current `manifest.md` zawiera `implementation_approval.mode` równy `approved`
  albo `conditional_revision`;
- `implementation_approval.artifact` wskazuje canonical
  `.sage/work/<cycle>/plan.md`;
- canonical `.sage/work/<cycle>/plan.md` istnieje na dysku;
- istnieje pre-turn evidence zatwierdzonego planu/scope: w v1 testujemy to jako
  wcześniejszy wpis w `.sage/.session-mutations.log` dla canonical `plan.md` z
  innym `turn_id` niż bieżący;
- target edit mieści się w `manifest.scope`.

Same-turn dopisanie `implementation_approval` bez pre-turn evidence nadal ma
blokować source/runtime/test/instruction edits. `[I]` używa
`mode: conditional_revision` i wymaga niepustego `revision`, ale nadal wymaga
pre-turn canonical plan/scope; agent może zrewidować `plan.md` w tej samej turze
tylko w granicach tej opisanej rewizji.

Pre-turn manifest-only evidence nie wystarcza. Jeśli `.session-mutations.log`
ma wcześniejszy wpis dla `manifest.md`, ale canonical `plan.md` nie istnieje
albo nie ma prior canonical `plan.md` evidence, hook nadal ma blokować.

## Files To Change

- `runtime/platforms/codex/hooks/tests/pre-tool-validate.bats`
  - Dodać failing tests dla legalnego same-turn bookkeepingu po prior approved
    plan/scope.
  - Dodać failing test dla `semantic_reclassification: accepted` dopisanego
    jako legalny checkpoint po approval.
  - Dodać pozytywny test dla same-turn `plan-milestone-1.md` bookkeeping:
    non-canonical milestone plan update nie blokuje pierwszego in-scope edit,
    jeśli canonical `plan.md` / manifest scope były zatwierdzone wcześniej.
  - Dodać `[I]` case: bounded same-turn canonical `plan.md` revision plus
    implementation jest allowowane wyłącznie z
    `implementation_approval.mode: conditional_revision`, niepustym `revision`
    i pre-turn canonical plan/scope evidence.
  - Zachować negatywne regresje: same-turn manifest/plan bez approval marker
    nadal blokuje source/runtime/test/instruction edits, szczególnie `AGENTS.md`.
  - Dodać negatywny marker-misuse test: same-turn manifest/plan z
    `implementation_approval`, ale bez pre-turn approved plan/scope evidence,
    nadal blokuje source/runtime/test/instruction edits, szczególnie `AGENTS.md`.
  - Dodać negatywny manifest-only misuse test: marker plus wcześniejszy log dla
    `manifest.md`, ale brak istniejącego canonical `plan.md` albo brak prior
    canonical `plan.md` evidence, nadal blokuje `AGENTS.md`.
  - Dostosować istniejące asercje na wording blokady, które pinują frazę
    `user approval`, żeby testy nie utrwalały starego mylącego recovery textu.

- `runtime/platforms/codex/hooks/pre-tool-validate.sh`
  - Doprecyzować `same_turn_bootstrapped_cycle`, żeby nie traktował każdego
    same-turn `manifest.md` / canonical `plan.md` write jako self-created
    approval.
  - Wprowadzić minimalny machine-checkable contract dla legalnego bookkeepingu
    po approval: `implementation_approval` w manifest frontmatter plus pre-turn
    evidence zatwierdzonego canonical `plan.md`/scope.
  - Wymagać, żeby canonical `plan.md` wskazany przez
    `implementation_approval.artifact` istniał; manifest-only evidence nie
    wystarcza.
  - Nadal fail-closed dla same-turn bootstrap bez markera i dla instruction
    mutation poza zatwierdzonym kontraktem.
  - Poprawić komunikat blokady tak, żeby nie sugerował braku user approval, gdy
    faktyczny problem to brak rozpoznawalnego approval/transition marker.

- `core/workflows/fix.workflow.md`
  - Dodać oficjalną opcję `[I] Revise and Implement in the same turn` tam, gdzie
    fix plan/scope może być warunkowo zaakceptowany po konkretnej rewizji.
  - Opisać boundary: tylko explicit bounded conditional approval; scope
    expansion, nowa decyzja, nowe ryzyko albo niejednoznaczna rewizja zatrzymują
    workflow.
  - Wskazać, że agent zapisuje `implementation_approval` w manifest frontmatter
    przed implementacją.

- `core/workflows/build.workflow.md`
  - Dodać `[I]` do plan checkpointu jako wariant obok review/skip/checkpointed/
    full autonomy, tylko dla konkretnie wskazanych rewizji planu.
  - Nie dodawać `[I]` do brief/spec checkpoints, jeśli nie prowadzą bezpośrednio
    do implementacji.

- `core/workflows/architect.workflow.md`
  - Dodać `[I]` do plan/milestone checkpointu, gdzie rewizja breakdownu może
    przejść od razu w implementację zatwierdzonego milestone.
  - Nie osłabiać design checkpointu: design revision bez implementacyjnego
    scope pozostaje normalnym checkpointem.

- `runtime/platforms/codex/setup/lib/agents-md.sh`
  - W generated Codex guidance dopisać krótki kontrakt `[I]`: warunkowe
    approval jest legalne tylko z konkretną rewizją, manifest markerem
    `implementation_approval` i wcześniejszym canonical `plan.md`/scope
    evidence; nie wolno używać go jako self-approval.

- `runtime/platforms/codex/setup/tests/stage3-agents-md.bats`
  - Dodać/zmienić tekstowe regresje dla wygenerowanego `AGENTS.md`, żeby
    potwierdzić obecność `[I]` i boundary self-approval.

## Tests

1. Najpierw uruchomić nowe targeted tests z `pre-tool-validate.bats`; mają
   failować przed implementacją.
2. Po implementacji uruchomić targeted hook tests obejmujące:
   - nowe legalne same-turn approval/bookkeeping cases;
   - legalny non-canonical `plan-milestone-1.md` same-turn bookkeeping case;
   - stare same-turn self-created manifest/plan negative cases;
   - marker misuse negative case bez pre-turn plan/scope evidence;
   - marker misuse negative case z manifest-only pre-turn evidence i brakiem
     canonical `plan.md`;
   - risky-path / `semantic_reclassification` case.
3. Uruchomić setup text tests dla generated `AGENTS.md` po zmianach guidance.
4. Uruchomić `bash -n runtime/platforms/codex/hooks/pre-tool-validate.sh` i
   `git diff --check`.

## Rollback

Jeśli marker contract okaże się zbyt szeroki, rollback polega na usunięciu
nowych allow cases z `pre-tool-validate.sh`, pozostawieniu negatywnych testów
bez zmian i wróceniu do planu z bardziej konserwatywnym agent-facing stopem.

## Risks

- Zbyt szeroki marker może umożliwić agentowe self-approval. Minimalizacja:
  marker musi być bounded, wymagać pre-turn plan/scope evidence i mieć marker
  misuse negative test.
- Zbyt wąski marker nie naprawi double-block pattern. Minimalizacja: testy
  muszą odtworzyć manifest phase transition oraz `semantic_reclassification`
  checkpoint.
- Zbyt dużo prose w generated `AGENTS.md` zwiększy instruction bloat.
  Minimalizacja: jedna krótka reguła w generated surface, szczegóły w workflow
  docs i testach.

## Done Criteria

- Wszystkie nowe i istniejące targeted hook tests przechodzą.
- Generated Codex guidance zawiera `[I]` i boundary self-approval.
- Workflow docs mają spójne checkpoint options i marker contract.
- `bin/sage status` nadal pokazuje tylko ten cykl jako aktywny.

## Verification

Completed 2026-05-14:

- `bats --filter 'same-turn|prior approved|semantic_reclassification checkpoint|milestone plan|conditional revision|marker without|manifest-only prior|prior-turn plan' runtime/platforms/codex/hooks/tests/pre-tool-validate.bats` — 10/10 pass.
- `bats --filter 'post-plan implementation mode choice' runtime/platforms/codex/setup/tests/stage3-agents-md.bats` — 1/1 pass.
- `bash -n runtime/platforms/codex/hooks/pre-tool-validate.sh runtime/platforms/codex/setup/lib/agents-md.sh runtime/platforms/codex/setup/generate-codex.sh` — pass.
- `git diff --check` — pass.
- `bats runtime/platforms/codex/hooks/tests/pre-tool-validate.bats` — 93/93 pass.
- `bats runtime/platforms/codex/setup/tests/stage3-agents-md.bats` — 52/52 pass.

## Handoff

Fix jest gotowy do commita. `implementation_approval` wymaga canonical
`plan.md` evidence i pozostaje fail-closed dla manifest-only/self-created
markerów. Następny logiczny krok po commit/push: wrócić do zaparkowanego
Architecta albo wybrać kolejny P0/P1 intake.
