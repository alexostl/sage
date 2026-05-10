---
title: "Plan: Alex-native operating model"
workflow: architect
phase: complete
status: completed
created: 2026-05-08
updated: 2026-05-08
cycle_id: "20260508-alex-native-operating-model"
spec: ".sage/work/20260508-alex-native-operating-model/spec.md"
---

# Plan: Alex-native operating model

## Goal

Wdrożyć Alex-native operating model prospektywnie: nowe artefakty `.sage` po
polsku, umiarkowany junior/vibe-coder conversation contract, oraz opcję
autonomicznej kontynuacji na checkpointach bez osłabienia istniejących gate'ów.

**Scope audit:** `.sage/work/20260508-alex-native-operating-model/scope-audit.md`.

## Constitution Constraints

- Tests before code: zmiany w instrukcjach/generatorach muszą dostać testy
  string-level lub generator-level przed zmianą zachowania.
- Checkpoints are sacred: autonomia jest opcją użytkownika, nie domyślnym
  obejściem approval gates.
- Decisions documented: każda istotna zmiana zakresu albo trade-off trafia do
  `.sage/decisions.md`.
- No silent failures: jeśli generator Claude/Codex nie przenosi kontraktu, test
  ma to pokazać.
- Changes reversible: rollback to zwykłe cofnięcie commitów; nie projektujemy
  reverse-migracji polskich artefaktów.

## Technology Decisions

- **Nie dodajemy shared snippet/include mechanizmu w v1.** Edytujemy istniejące
  shared source: `core/workflows/*.workflow.md`,
  `core/capabilities/**/SKILL.md` i `develop/templates/**`.
- **Port updates są kompaktowe.** Codex `AGENTS.md` i Claude `CLAUDE.md`/command
  preambles dostają tylko always-loaded kontrakt potrzebny w runtime; szczegóły
  zostają w core workflow/capability text.
- **Autonomia po `spec` jest warunkowa.** Agent może przejść przez planowanie,
  ale zatrzymuje się przed implementation, jeśli plan ujawnia istotną decyzję
  architektoniczną, scope expansion albo ważne pytanie.
- **Autonomia po `plan` jest głównym fast path.** To najbezpieczniejszy moment,
  bo scope, tasks i verification path są już opisane.

## Milestone 1: Core Workflow Contract

Delivers: shared behavior for future `.sage` artifacts and checkpoint UX.

- [x] **Task 1:** Add dedicated failing shared-text assertions for Alex-native core contract
  - **Read first:** `.sage/work/20260508-alex-native-operating-model/spec.md`
  - **Files:** add `runtime/platforms/codex/setup/tests/alex-native-core-text.bats`
  - **Action:** Add a dedicated shared-text regression with exact file lists and assertions. It must check `core/constitution/sage-process.constitution.md`, `core/capabilities/orchestration/sage-navigator/SKILL.md`, required workflow files, required capability files, and templates. Do not use Codex Stage 3 as core coverage.
  - **Test:** The new assertions should fail before implementation.
  - **Verify:** `bats runtime/platforms/codex/setup/tests/alex-native-core-text.bats`
  - **Depends on:** none

- [x] **Task 2:** Update core workflow checkpoint language
  - **Read first:** `core/constitution/sage-process.constitution.md`, `core/workflows/build.workflow.md`, `core/workflows/architect.workflow.md`, `core/workflows/design.workflow.md`, `core/workflows/analyze.workflow.md`, `core/workflows/fix.workflow.md`
  - **Files:** listed files above
  - **Action:** Add future-only Polish artifact prose guidance, checkpoint summaries with 1-3 links, and autonomy options after `spec`/`plan` where applicable. Include `analyze` for decision/finding checkpoints. Keep `fix` lighter: clearer root-cause explanation and evidence links, no unnecessary autonomy option.
  - **Test:** Existing and new shared-text assertions from Task 1.
  - **Verify:** `bats runtime/platforms/codex/setup/tests/alex-native-core-text.bats`
  - **Depends on:** Task 1

- [x] **Task 3:** Update core capability prompts
  - **Read first:** `core/capabilities/elicitation/deep-elicit/SKILL.md`, `core/capabilities/elicitation/quick-elicit/SKILL.md`, `core/capabilities/planning/specify/SKILL.md`, `core/capabilities/planning/plan/SKILL.md`, `core/capabilities/orchestration/sage-navigator/SKILL.md`, `core/capabilities/orchestration/build-loop/SKILL.md`
  - **Files:** listed capability files above
  - **Action:** Encode the junior/vibe-coder conversation contract: short context before decisions, one question at a time, recommendation with choices, inspect repo before asking, and link key artifact sections after checkpoints.
  - **Test:** Shared-text assertions from Task 1 must include per-file groups for elicitation, planning, navigator, and build-loop behavior.
  - **Verify:** `bats runtime/platforms/codex/setup/tests/alex-native-core-text.bats`
  - **Depends on:** Task 2

🔒 CHECKPOINT: Core text contains the behavior contract without adding a new shared snippet/include mechanism.

## Milestone 2: Templates and Port Instruction Surfaces

Delivers: future artifacts and runtime agents inherit the contract.

- [x] **Task 4:** Update future artifact templates
  - **Read first:** `develop/templates/manifest-template.md`, `develop/templates/spec/full.spec-template.md`, `develop/templates/spec/minimal.spec-template.md`, `develop/templates/plan/standard.plan-template.md`, `develop/templates/architecture/decision-template.md`
  - **Files:** listed templates above
  - **Action:** Add concise guidance that generated artifact prose should be Polish by default in self-host context while preserving Sage framework terms. Do not rename template fields or artifact filenames.
  - **Test:** Shared-text assertions from Task 1 must include per-template checks.
  - **Verify:** `bats runtime/platforms/codex/setup/tests/alex-native-core-text.bats`
  - **Depends on:** Task 3

- [x] **Task 5:** Update Codex compact always-loaded instruction surface
  - **Read first:** `runtime/platforms/codex/setup/lib/agents-md.sh`, `runtime/platforms/codex/setup/tests/stage3-agents-md.bats`
  - **Files:** `runtime/platforms/codex/setup/lib/agents-md.sh`, `runtime/platforms/codex/setup/tests/stage3-agents-md.bats`
  - **Action:** Add a compact Alex-native operating contract to generated `AGENTS.md`: future Polish artifact prose, short checkpoint context with links, one-question-at-a-time decisions, and autonomy stop conditions. Keep within compactness constraints.
  - **Test:** Stage 3 generated `AGENTS.md` tests for the new contract and existing byte-size compactness test.
  - **Verify:** `bats runtime/platforms/codex/setup/tests/stage3-agents-md.bats`
  - **Depends on:** Task 4

- [x] **Task 6:** Update Claude compact runtime surfaces and regression coverage
  - **Read first:** `runtime/platforms/claude-code/setup/generate-claude-code.sh`, `runtime/platforms/claude-code/setup/generate-plugin.sh`
  - **Files:** `runtime/platforms/claude-code/setup/generate-claude-code.sh`, `runtime/platforms/claude-code/setup/generate-plugin.sh` if needed, add `runtime/platforms/claude-code/setup/tests/generate-claude-code.bats`
  - **Action:** Add equivalent compact contract to `CLAUDE.md` and relevant command preambles. Treat plugin generation as inherited from the Claude generator; test or smoke-check that extraction still sees the updated text.
  - **Test:** New Bats regression creates a temp target with `.sage/config.yaml`, runs `generate-claude-code.sh`, then asserts generated `CLAUDE.md` and `.claude/commands/*build*.md` / `*architect*.md` contain the compact Alex-native contract and autonomy stop language. It also runs `generate-plugin.sh` into a temp output or extracts its generated navigator skill to verify inherited text if implementation touches plugin generation.
  - **Verify:** `bats runtime/platforms/claude-code/setup/tests/generate-claude-code.bats`
  - **Depends on:** Task 5

- [x] **Task 6.5:** Wire Claude tests into CI if added
  - **Read first:** `.github/workflows/codex-port-ci.yml`
  - **Files:** `.github/workflows/codex-port-ci.yml`
  - **Action:** If Task 6 adds a Claude Bats test, update CI paths and jobs/steps so Claude generator tests run alongside Codex setup tests on relevant changes.
  - **Test:** Workflow YAML parses and local Bats command passes.
  - **Verify:** `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/codex-port-ci.yml")'` and `bats runtime/platforms/claude-code/setup/tests`
  - **Depends on:** Task 6

🔒 CHECKPOINT: Codex and Claude both carry compact runtime guidance while detailed behavior remains in core.

## Milestone 3: Integrated Verification and Dogfood QA

Delivers: confidence that the behavior works as intended and remains reversible.

- [x] **Task 7:** Run focused setup/generator suites
  - **Read first:** `.github/workflows/codex-port-ci.yml`, relevant setup test files
  - **Files:** no implementation files unless tests reveal a bug
  - **Action:** Run Codex setup tests and the new Claude generator test. Fix only issues in the approved scope.
  - **Test:** Existing and newly added tests.
  - **Verify:** `bats runtime/platforms/codex/setup/tests` and `bats runtime/platforms/claude-code/setup/tests`
  - **Depends on:** Task 6.5

- [x] **Task 8:** Dogfood the conversational contract [DOC]
  - **Read first:** `.sage/work/20260508-alex-native-operating-model/spec.md`
  - **Output:** `.sage/work/20260508-alex-native-operating-model/qa-report.md`
  - **Action:** Run a short simulated Standard+ workflow prompt or harness-style prompt and record whether the agent gives short context, asks one question at a time, links key artifact sections, and respects autonomy stop conditions.
  - **Criteria:** Report includes PASS/WARN/FAIL for the 20-30% style shift and notes any follow-up.
  - **Depends on:** Task 7

- [x] **Task 9:** Final verification and close-out
  - **Read first:** plan and qa-report
  - **Files:** `.sage/work/20260508-alex-native-operating-model/plan.md`, `.sage/work/20260508-alex-native-operating-model/manifest.md`, `.sage/decisions.md`
  - **Action:** Update plan checkboxes, manifest handoff, and decisions. Confirm rollback path is ordinary git rollback and that no historical `.sage` files were migrated.
  - **Test:** `git diff --check`
  - **Verify:** paste final test outputs and summarize remaining risk.
  - **Depends on:** Task 8

🔒 CHECKPOINT: Implementation matches spec, tests pass, dogfood QA recorded, and no historical `.sage` migration occurred.

## Gate Log

| Task | Gate 1 (Spec) | Gate 2 (Constitution) | Gate 3 (Quality) | Gate 4 (Hallucination) | Gate 5 (Verify) |
|------|:---:|:---:|:---:|:---:|:---:|
| Task 1 | PASS | PASS | PASS | PASS | PASS |
| Task 2 | PASS | PASS | PASS | PASS | PASS |
| Task 3 | PASS | PASS | PASS | PASS | PASS |
| Task 4 | PASS | PASS | PASS | PASS | PASS |
| Task 5 | PASS | PASS | PASS | PASS | PASS |
| Task 6 | PASS | PASS | PASS | PASS | PASS |
| Task 6.5 | PASS | PASS | PASS | PASS | PASS |
| Task 7 | PASS | PASS | PASS | PASS | PASS |
| Task 8 | PASS | PASS | PASS | PASS | PASS |
| Task 9 | PASS | PASS | PASS | PASS | PASS |

## Completion Notes

Implemented without adding a new shared snippet/include mechanism. Historical
`.sage` artifacts were not migrated. Rollback remains ordinary git rollback to
the previous commit. Supported self-host runtime surfaces now covered: shared
core, future templates, Codex generator, Claude Code generator, and CI.
