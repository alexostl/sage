---
cycle_id: "20260509-cycle-workflow-entry-enforcement-fix"
title: "Plan: Batch 1 workflow entry and resume contract"
workflow: fix
phase: fix-scope-gate
status: in-progress
created: 2026-05-13
updated: 2026-05-13
classification: systemic
---

# Plan: Batch 1 workflow entry and resume contract

## Klasyfikacja

**Systemic fix.**

Ten batch dotyka generated instruction contract, workflow guidance, Codex UX
visibility, hook/runtime ownership predicates i harness assertions. To jest
więcej niż surgical/moderate patch, bo zmienia kontrakt zachowania agenta w
kilku warstwach jednocześnie.

## Zatwierdzony problem

Root cause: Batch 1 nie ma jednego end-to-end kontraktu
`state transition before work`, który mówi agentowi:

1. rozpoznaj mandate i workflow/cykl;
2. utwórz albo wznów obserwowalny stan `.sage`;
3. dopiero po zmianie frontmatter powiedz, jaki `status`/`phase` się zmienił;
4. dla Standard+ pracy w Codex utrzymuj native task-plan jako warstwę
   obserwowalności;
5. mutuj artefakty/kod dopiero po właściwym gate;
6. respektuj `active_session_id`/lease ownership i nie mieszaj capture-only
   `.sage/**` z implementation paths.

## Files to change

### Workflow and instruction contract

- `core/capabilities/orchestration/sage-navigator/SKILL.md`
  - dodać krótką checklistę state transition dla Standard+/Moderate+ entry i
    resume;
  - nazwać task-plan jako Codex visibility layer, nie zamiennik artefaktów;
  - doprecyzować, że fix-trigger w instruction/process files nie jest zwykłym
    direct edit, jeśli dotyka canonical terms albo workflow behavior.

- `core/workflows/continue.workflow.md`
  - doprecyzować formalne resume `intake`/`paused`: manifest first,
    `status: in-progress`, właściwa faza workflow, `active_session_id` jeśli
    dostępny, komunikat po zmianie;
  - opisać, że wznowienie parked cycle jest legalne dopiero po tym transition.

- `core/workflows/fix.workflow.md`
  - dodać guidance dla "find and fix" w plikach instrukcji/procesu:
    najpierw krótka diagnoza i scope gate; Tier 1 direct edit zostaje tylko dla
    oczywistych, niekanonicznych literówek.

- `core/constitution/sage-process.constitution.md`
  - zsynchronizować always-loaded zasadę z ostrzejszym kontraktem Batcha 1,
    żeby self-host i generated target nie dryfowały.

- `runtime/platforms/codex/setup/lib/agents-md.sh`
  - zaktualizować generated Codex `AGENTS.md`: state transition sequence,
    post-fact disclosure, task-plan visibility, fix-trigger guard i
    `active_session_id`/lease boundary.

### Runtime and harness guardrails

- `runtime/platforms/codex/hooks/lib/active_init.sh`
  - jeżeli kod już spełnia lease/capture predicate, zostawić behavior i
    ewentualnie doprecyzować komentarze; jeśli test pokaże lukę, poprawić
    resolver minimalnie.

- `runtime/platforms/codex/hooks/pre-tool-validate.sh`
  - nie rozszerzać Batcha 1 na mutation-intent/preflight z Batcha 2;
  - dodać tylko brakujące guardrail wording/predicate dla lease/capture, jeśli
    testy pokażą, że obecna logika nie pokrywa intencji.

- `runtime/platforms/codex/harness/v11-scenarios.json`
  - utrzymać `04-fix-trigger` jako release-blocker dla diagnose/scope zamiast
    direct edit;
  - jeśli trzeba, doprecyzować transcript patterns dla entry/resume/disclosure
    i task-plan visibility bez wciągania scenariusza 03 jako scope Batcha 1.

- `runtime/platforms/codex/harness/prompts/04-fix-trigger.txt`
  - zmienić tylko jeśli obecny prompt jest za mało jednoznaczny dla canonical
    instruction/process risk; w przeciwnym razie zostawić.

### Batch bookkeeping

- `.sage/work/20260509-agent-resume-intake-cycle-fix/manifest.md`
- `.sage/work/20260509-cycle-state-disclosure-fix/manifest.md`
- `.sage/work/20260509-codex-task-plan-visibility-fix/manifest.md`
- `.sage/work/20260509-fix-trigger-gate-fix/manifest.md`
- `.sage/work/20260509-active-cycle-lease-lock/manifest.md`

Po zweryfikowanej implementacji oznaczyć te sibling intakes jako skonsumowane
przez anchor cycle Batcha 1, zamiast zostawiać je jako pozornie otwarte prace.
Zmiana ma być bookkeeping-only: krótka sekcja wskazująca anchor cycle,
`status: completed`, `phase: completed`, bez dopisywania nowego zakresu
implementacyjnego do tych cykli.

### Tests

- `runtime/platforms/codex/setup/tests/stage3-agents-md.bats`
  - dodać/rozszerzyć asercje dla generated `AGENTS.md`:
    - entry/resume jako sekwencja manifest -> disclosure -> artifacts/code;
    - Codex task-plan jako visibility layer;
    - fix-trigger guard dla instruction/process files;
    - `active_session_id`/lease boundary i conceptual `.sage/**` exception.

- `runtime/platforms/codex/hooks/tests/pre-tool-validate.bats`
  - dodać brakujące regresje dla:
    - obca sesja nie mutuje aktywnego `in-progress` cyklu;
    - równoległa conceptual capture/planning-only praca w `intake`/`paused`
      jest dozwolona;
    - capture-only `.sage/**` zmieszane z implementation path jest blokowane.
  - Jeśli istniejące testy już pokrywają przypadek, dopisać tylko brakujący
    wariant albo komentarz porządkujący.

- `runtime/platforms/codex/hooks/tests/active_init.bats`
  - uruchomić jako minimal verification, jeśli `active_init.sh` pozostaje w
    scope;
  - dopisać test tylko wtedy, gdy obecne przypadki nie pokrywają path intent,
    parked capture albo active ownership boundary potrzebnych dla Batcha 1.

- `runtime/platforms/codex/harness/tests/aggregate-signals.bats`
  - zmienić tylko jeśli modyfikacja `v11-scenarios.json` wymaga aktualizacji
    agregatu.

## Files not in scope

- `20260510-mutation-intent-preflight-gap` i scenariusz 03 jako osobny fix
  pozostają w Batchu 2.
- Binary asset mutation contract zostaje w Batchu 2.
- Closeout/handoff/gits steps zostają w Batchu 3.
- Loader path / duplicate entrypoints / hooks feature flag zostają w Batchu 4.

## Implementation sequence

1. Zaktualizować instruction/workflow contract w małych patchach:
   navigator -> continue -> fix workflow -> constitution/generated AGENTS.
2. Dodać deterministic Stage 3 tests dla generated wording.
3. Dodać albo potwierdzić hook tests dla lease/capture predicate.
4. Doprecyzować harness scenario 04, jeśli deterministic wording zmienia
   oczekiwane transcript patterns.
5. Uruchomić targeted tests i sprawdzić diff.

## Verification

Minimalny zestaw:

- `uvx bats runtime/platforms/codex/setup/tests/stage3-agents-md.bats`
- `uvx bats runtime/platforms/codex/hooks/tests/active_init.bats`
- `uvx bats runtime/platforms/codex/hooks/tests/pre-tool-validate.bats`
- `uvx bats runtime/platforms/codex/harness/tests/aggregate-signals.bats`
- `bash -n runtime/platforms/codex/setup/lib/agents-md.sh`
- `bash -n runtime/platforms/codex/hooks/pre-tool-validate.sh`
- `bash -n runtime/platforms/codex/hooks/lib/active_init.sh`
- `git diff --check`

Real-agent harness policy:

- Jeśli implementacja zmienia generated Codex contract, harness scenarios albo
  runtime/hook behavior związany z entry/resume/fix-trigger, real-agent harness
  dla scenariuszy `04-fix-trigger` i `06-action-creates-or-resumes-manifest`
  jest wymagany przed oznaczeniem cyklu jako completed.
- Minimum completion evidence to aktualne real-agent transcripts dla `04` i
  `06`. Jeżeli obecny runner nie wspiera targeted-only run, uruchomić pełny
  `runtime/platforms/codex/harness/run-harness.sh`.
- Jeśli real-agent harness nie może zostać uruchomiony albo nie produkuje
  aktualnych transcriptów dla release-blocker scenarios, cykl nie przechodzi do
  `completed`. Zostaje `paused` albo `in-progress` z jawnie opisanym blockerem
  verification, ale bez completion claimu.

## Rollback

Zmiany są tekstowe i testowe. Rollback: wycofać patch do wymienionych plików,
zostawiając artefakty `.sage/work/20260509-cycle-workflow-entry-enforcement-fix/*`
jako record decyzji i planu. Nie ma migracji danych ani zmian formatu
artefaktów wymagających konwersji.

## Ryzyka

- Zbyt szerokie wording może zacząć wymuszać pełny workflow dla drobnych
  literówek. Mitigation: zachować explicit wyjątek dla oczywistych Tier 1
  direct edits.
- Lease lock może zablokować legalną pracę koncepcyjną. Mitigation:
  testy muszą potwierdzić wyjątek dla capture/planning-only `.sage/**` w
  `intake`/`paused`.
- Task-plan UI nie jest artefaktem Sage i nie może stać się formalnym źródłem
  prawdy. Mitigation: wording mówi "visibility layer", nie gate.
