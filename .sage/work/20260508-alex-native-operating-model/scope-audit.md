---
title: "Scope Audit: Alex-native operating model"
workflow: architect
phase: plan
status: completed
created: 2026-05-08
cycle_id: "20260508-alex-native-operating-model"
---

# Scope Audit: Alex-native operating model

## Purpose

Sprawdzić, czy plan wdrożenia Alex-native operating model nie pomija ważnych
powierzchni w repozytorium przed rozpoczęciem Milestone 1.

## Included Surfaces

### Shared core behavior

- `core/constitution/sage-process.constitution.md`
- `core/capabilities/orchestration/sage-navigator/SKILL.md`
- `core/workflows/build.workflow.md`
- `core/workflows/architect.workflow.md`
- `core/workflows/design.workflow.md`
- `core/workflows/analyze.workflow.md`
- `core/workflows/fix.workflow.md`
- `core/capabilities/elicitation/deep-elicit/SKILL.md`
- `core/capabilities/elicitation/quick-elicit/SKILL.md`
- `core/capabilities/planning/specify/SKILL.md`
- `core/capabilities/planning/plan/SKILL.md`
- `core/capabilities/orchestration/build-loop/SKILL.md`

### Future artifact templates

- `develop/templates/manifest-template.md`
- `develop/templates/spec/full.spec-template.md`
- `develop/templates/spec/minimal.spec-template.md`
- `develop/templates/plan/standard.plan-template.md`
- `develop/templates/architecture/decision-template.md`

### Active runtime platform surfaces

Project config says `platform: "claude-code,codex"`, so v1 covers:

- `runtime/platforms/codex/setup/lib/agents-md.sh`
- `runtime/platforms/codex/setup/tests/stage3-agents-md.bats`
- new dedicated shared-text test under `runtime/platforms/codex/setup/tests/`
- `runtime/platforms/claude-code/setup/generate-claude-code.sh`
- `runtime/platforms/claude-code/setup/generate-plugin.sh` as inherited downstream
- new Claude generator regression under `runtime/platforms/claude-code/setup/tests/`
- `.github/workflows/codex-port-ci.yml`, if needed, so new Claude tests are not dead local-only coverage

### State and audit artifacts

- `.sage/work/20260508-alex-native-operating-model/*`
- `.sage/decisions.md`

## Explicitly Excluded From v1

- Historical files in `.sage/work` and `.sage/docs`.
- `runtime/platforms/antigravity/**`: present in repo, but not active in this
  self-host project config and not requested for this cycle.
- `runtime/platforms/generic/CLAUDE.md`: static Tier 2 generic instructions,
  not part of the active `claude-code,codex` self-host setup.
- `core/autoresearch/**`: has its own runtime and brief parsing, but this cycle
  targets conversational workflow artifacts, not the autoresearch engine.
- Broad docs such as `README.md` and platform READMEs unless tests reveal a
  broken public promise.

## Plan Corrections From Review

- Add `core/constitution/sage-process.constitution.md` to Milestone 1.
- Add `core/workflows/analyze.workflow.md` to Milestone 1.
- Replace broad `rg` checks with a dedicated shared-text regression test that
  names exact files and expected behaviors.
- Define the Claude test shape before implementation starts.
- Check Claude generator/plugin feasibility early, before core/template edits
  make the plan expensive to unwind.
