---
cycle_id: "20260509-closeout-documentation-mutation-model"
title: "Plan: Batch 3 closeout lifecycle fix"
workflow: fix
phase: completed
status: completed
created: 2026-05-13
updated: 2026-05-13
classification: Systemic
---

# Plan: Batch 3 closeout lifecycle fix

## Classification

**Systemic fix.** Ten batch dotyka jednego kontraktu, ale na kilku
powierzchniach: workflow guidance, generated Codex instructions, hook resolver,
PreToolUse recovery, PostToolUse audit i testy. Nie implementować częściowo bez
zatwierdzonego scope.

## Approved Root Cause

Sage ma rozproszony model końca cyklu. Brakuje jednego kontraktu:

1. final self-review,
2. wszystkie artefakty/decyzje/handoff przed closeoutem,
3. `manifest.status: completed` jako ostatnia mutacja cyklu,
4. po closeoucie tylko status stage/commit i pytanie o handoff zmian bieżącego
   cyklu,
5. bez domyślnego `push` i bez dopisywania epilogów do zamkniętego `.sage`.

Subagent review zaakceptował diagnozę bez blockerów. Uwaga przeniesiona do
planu: patch wskazujący `completed` cycle nie może spaść na unrelated newest
active cycle.

## Minimalism Constraint

Przed implementacją zrobić minimization pass: czy ten sam cel da się osiągnąć
mniejszą zmianą, reuse istniejącej logiki, konsolidacją wordingów albo testem
zamiast nowej instrukcji. To nie jest zakaz dodawania; jeśli dodatek jest
potrzebny, dodać najmniejszy element, który zamyka problem.

- Generated `AGENTS.md` ma dostać lakoniczny kontrakt closeoutu, nie długi
  nowy kodeks.
- Edge-case'y preferencyjnie egzekwować przez małe mechaniczne hooki i
  targeted tests, nie przez rozbudowany prompt surface.
- Jeśli istniejący resolver + completed-cycle result + recovery wording
  wystarczą, nie dodawać szerokiej nowej klasyfikacji mutacji.
- Jeśli workflow wording da się naprawić wspólnym krótkim blokiem albo
  istniejącym kontraktem, nie duplikować zasad w wielu miejscach.

## Scope

### Runtime hooks

- `runtime/platforms/codex/hooks/lib/active_init.sh`
  - Dodać completed-specific resolution dla ścieżek
    `.sage/work/<cycle>/...`, gdy manifest tego cyklu ma `status: completed`.
  - Completed-specific result ma wygrać z unrelated newest active cycle.
  - Nie aktywować completed cycle do implementacji; to jest recovery context.

- `runtime/platforms/codex/hooks/pre-tool-validate.sh`
  - Dodać recovery message dla completed-cycle mutation:
    "manifest został prawdopodobnie zamknięty przed artefaktami; poprawna
    ścieżka to explicit reopen/scope decision albo kontynuacja handoffu bez
    mutacji `.sage`".
  - Zachować twarde blokowanie implementation/runtime/test path po completed
    cycle.
  - Dodać wąską regułę decisions-only repo hygiene dla pojedynczej oczywistej
    zmiany repo hygiene, np. `.gitignore`, gdy nie dotyka runtime, hooków,
    workflowów, testów, builda, security ani release packaging.
  - Nie robić standalone `.gitignore` bypassu: legalna ścieżka to jeden
    repo-hygiene file plus wymagany wpis w `.sage/decisions.md`.
  - Repo hygiene nie może być dopisywane do zamkniętego cyklu jako ukryte
    scope expansion; wymaga wpisu w `.sage/decisions.md`.

- `runtime/platforms/codex/hooks/post-tool-check.sh`
  - Zostawić jako audit po fakcie, ale doprecyzować/utrzymać incident
    `post_completion_mutation` jako sygnał jakości, nie główną ścieżkę
    prowadzenia agenta.
  - Jeśli zmieni się completed-cycle marker albo wording, dostosować testy.

### Workflow and generated guidance

- `core/workflows/build.workflow.md`
  - Dodać final self-review przed closeoutem.
  - Uporządkować kolejność: verification/plan/decisions/handoff przed
    `manifest.status: completed`.
  - Po closeoucie agent ma raportować stage/commit status i pytać o handoff.
    Nie pyta domyślnie o push.

- `core/workflows/fix.workflow.md`
  - Dodać analogiczny closeout order dla fixów: decyzje i artifact updates
    przed manifest closeout.
  - W finalnym checkpointcie rozdzielić "fix verified / closeout approved" od
    git handoff stage/commit.

- `core/workflows/architect.workflow.md`, `core/workflows/design.workflow.md`,
  `core/workflows/analyze.workflow.md`, `core/workflows/research.workflow.md`,
  `core/workflows/qa.workflow.md`, `core/workflows/review.workflow.md`
  - Przejrzeć completion wording i ujednolicić tylko tam, gdzie workflow
    mutuje `.sage` przy zamykaniu.
  - Nie rozdmuchiwać krótkich workflowów; wspólny kontrakt ma być zwięzły.

- `core/constitution/sage-process.constitution.md`
  - Jeśli potrzebne, dopisać jedną zwięzłą zasadę systemową o closeout order i
    post-closeout git handoff.

- `runtime/platforms/codex/setup/lib/agents-md.sh`
  - Wygenerowany `AGENTS.md` ma dostać krótki operating-kernel fragment:
    closeout order, no post-closeout `.sage` epilogue, stage/commit handoff,
    no default push.

### Tests

- `runtime/platforms/codex/hooks/tests/active_init.bats`
  - Test: patch targetuje completed cycle i istnieje unrelated active cycle;
    resolver zwraca completed-specific result, nie active cycle.
  - Test: completed cycle bez active cycle ma rozpoznawalny result, nie gołe
    `none`.

- `runtime/platforms/codex/hooks/tests/pre-tool-validate.bats`
  - Test: `.sage/work/<completed>/manifest.md` albo inny artifact po
    completed cycle dostaje completed-cycle recovery message.
  - Test: implementation/runtime/test path po completed cycle nadal blokuje.
  - Test: pojedynczy `.gitignore` repo hygiene bez aktywnego cyklu przechodzi
    tylko razem z `.sage/decisions.md`; standalone `.gitignore` ma dostać
    instrukcję decisions-only.
  - Test: ta sama `.gitignore` zmiana nie przechodzi, jeśli patch dotyka
    runtime/hook/workflow/test/security/release paths.

- `runtime/platforms/codex/hooks/tests/post-tool-check.bats`
  - Zachować istniejące regresje dla `post_completion_mutation`.
  - Dostosować tylko jeśli nowy completed-cycle kontrakt zmienia marker albo
    expected wording.

- `runtime/platforms/codex/setup/tests/stage3-agents-md.bats`
  - Test generated `AGENTS.md`: closeout order.
  - Test generated `AGENTS.md`: post-closeout next-step to stage/commit
    handoff; `push` nie jest domyślnym pytaniem.
  - Test generated `AGENTS.md`: local handoff po closeoucie nie dopisuje
    epilogu do `.sage`.

### Bookkeeping after verified implementation

Po zielonej weryfikacji, ale przed finalnym closeoutem:

- oznaczyć sibling intake manifests jako `status: completed` i
  `folded_into: 20260509-closeout-documentation-mutation-model`;
- nie dopisywać ukrytej implementacji do tych sibling cycles;
- dopisać decyzję o completion checkpoint do `.sage/decisions.md`.

Sibling manifests:

- `.sage/work/20260510-closeout-ordering-workflow-hook-fix/manifest.md`
- `.sage/work/20260510-post-closeout-handoff-doc-mutation-fix/manifest.md`
- `.sage/work/20260513-post-closeout-git-next-step-build/manifest.md`
- `.sage/work/20260513-lightweight-repo-hygiene-decisions-fix/manifest.md`

## Non-goals

- Nie dodawać domyślnego `push` do post-closeout next-step.
- Nie otwierać osobnego worktree lifecycle modelu; to Batch 8.
- Nie rozwiązywać Batcha 4 loader/navigator drift poza minimalnym generated
  `AGENTS.md` wording wymaganym przez ten fix.
- Nie przepisywać starych entries w `.sage/decisions.md`, które historycznie
  mówiły `stage/commit/push`; superseded wording ma być w nowych artefaktach.
- Nie luzować ochrony completed cycle dla implementation/runtime/test paths.

## Rollback

Zmiany są tekstowo-runtime i testowe. Rollback:

1. Cofnąć zmiany w hookach i generated guidance.
2. Cofnąć testy dodane dla completed-cycle recovery i stage/commit handoff.
3. Zostawić decyzje/plan jako audit trail albo dopisać decyzję o revertecie,
   jeśli implementacja była już zatwierdzona.

## Verification

Minimalna weryfikacja przed completion checkpoint:

```bash
bats runtime/platforms/codex/hooks/tests/active_init.bats
bats runtime/platforms/codex/hooks/tests/pre-tool-validate.bats
bats runtime/platforms/codex/hooks/tests/post-tool-check.bats
bats runtime/platforms/codex/setup/tests/stage3-agents-md.bats
bash -n runtime/platforms/codex/hooks/lib/active_init.sh \
  runtime/platforms/codex/hooks/pre-tool-validate.sh \
  runtime/platforms/codex/hooks/post-tool-check.sh \
  runtime/platforms/codex/setup/lib/agents-md.sh
git diff --check
```

Jeśli plan dotknie dodatkowego workflow albo generated surface, dodać
odpowiedni targeted test. Full real-agent harness nie jest domyślnie wymagany
na plan gate; decyzję o nim podjąć po implementacji, gdy będzie jasne, czy
zmiana wpływa na release-blocker transcript behavior.
