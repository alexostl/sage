---
cycle_id: "20260508-alex-native-operating-model"
title: "Alex-native operating model"
workflow: architect
phase: folded
status: completed
created: 2026-05-08
updated: 2026-05-09
owner: alexostl
folded_into: "20260509-runtime-process-reliability-patch"
scope:
  - ".sage/work/20260508-alex-native-operating-model/*"
  - ".sage/decisions.md"
  - "core/**"
  - "develop/templates/**"
  - "runtime/platforms/codex/**"
  - "runtime/platforms/claude-code/**"
  - ".github/workflows/*"
  - ".agents/skills/**"
---

# Cycle: Alex-native operating model

## State

**Current phase:** follow-up — implementation committed, but the cycle stays
open for real-world validation.
**Next step:** Test in normal Sage work, then decide whether to adjust runtime
surfaces after first real usage.
**Artifacts:**
- brief.md: exists — approved
- spec.md: exists — approved for review
- plan.md: exists — approved for review
- scope-audit.md: exists — completed before Milestone 1
- implementation: complete — committed and pushed as `cf28dea`
- quality-gates: passed — Codex setup, Claude setup, Codex hooks, diff check
- qa-report.md: exists — PASS
- real-use-findings.md: exists — open findings from first real-use test
- dummy-project-real-work-report.md: exists — two real Codex sessions on
  isolated Project Dummy copies
- dummy-project-brief-test-plan.md: exists — brief-derived scenario matrix
- dummy-project-brief-test-report.md: exists — six real Codex sessions on
  isolated Project Dummy copies
- dummy-project-artifact-docs-report.md: exists — controlled build/architect/fix
  artifact generation tests for `brief/spec/plan/manifest`
- design-review.md: not run; folded runtime/process follow-ups supersede this
  open validation state

## Context summary

This cycle exists because Sage Self Host is now intentionally "self": optimized
for Alex rather than upstream parity. The user is not asking for a major Sage
redesign; the desired change is a 20-30% style and language adjustment that
keeps the current methodology intact. The most important nuance is that Sage
currently assumes the user reads full generated artifacts, while Alex often
needs concise conversational context plus links to the key saved fragments
instead. The design should therefore focus on future artifact language,
conversation/checkpoint behavior, and safe autonomy options, not on historical
document migration.

## Decisions so far

- New `.sage` artifact content should be written in Polish, while framework
  names and technical terms stay stable.
- Historical `.sage/work` and `.sage/docs` files must not be migrated or
  translated in v1.
- The conversation style should shift moderately toward junior/vibe-coder
  support: one question at a time, more context, fewer hidden assumptions, and
  links to the important saved sections.
- Checkpoints should include an optional autonomous-continuation path, but
  normal checkpointed flow remains the default.
- The change should live mostly in `core/`; Codex and Claude ports should
  inherit or generate the behavior where possible.
- Alex approved the brief and selected [A] Review for the design checkpoint.
- Auto-review findings were incorporated: no new shared snippet/include
  mechanism in v1, direct core edits, compact port mirrors, concrete template
  boundaries, and conditional autonomy after `spec`.
- Alex selected [A] Review for plan and explicitly asked to stop before
  Milestone 1 to see the review effects.
- Pre-Milestone scope audit added `sage-process.constitution.md`,
  `analyze.workflow.md`, dedicated shared-text tests, explicit Claude test
  shape, optional CI wiring, and explicit exclusions for Antigravity/Generic.

## Folded status

Real-use findings z tego follow-up zostały wciągnięte do
`.sage/work/20260509-runtime-process-reliability-patch/`. Patch domyka
runtime/process część walidacji: polska proza w nowych dopiskach `.sage`,
post-plan `[C]`/`[F]`, no-spontaneous-fix guidance i harness oraz runtime
localization dla najważniejszych `sage status`/`sage doctor` surfaces. Brak
osobnego `design-review.md` nie blokuje zamknięcia tego follow-up, bo obecny
patch zastąpił go focused review i testami runtime/process.

## Open questions

- Czy `developer_instructions` in `.codex/config.toml` should also carry the
  Alex-native compact contract, or is `AGENTS.md` enough in practice?
- Czy `AGENTS.md` and `CLAUDE.md` need broader Polish translation, or should
  only `.sage` artifacts be Polish while runtime instructions stay mostly
  English?
- Czy the 20-30% junior/vibe-coder style shift feels right during first real
  work cycles, or does it need calibration?
- Jakie user-facing runtime surfaces muszą być po polsku poza `.sage`
  artifacts: CLI output, generated slash commands, session hooks, doctor/status,
  config `developer_instructions`?
- Jaki guardrail ma zatrzymywać agenta przed spontaniczną naprawą po samym
  zgłoszeniu błędu/findingu?

## Provenance

| Key | Value |
|-----|-------|
| Repo | `https://github.com/alexostl/sage.git` |
| Branch | `selfhost` |
| Commit | `cf28dea` |
| Working tree | `clean after commit; .sage cycle notes are local/ignored` |

## Handoff guidance

This is intentionally not fully closed from a product-behavior perspective.
Before opening a follow-up implementation, read `real-use-findings.md` and
`dummy-project-real-work-report.md`, then `dummy-project-brief-test-plan.md`
and `dummy-project-brief-test-report.md`. The Project Dummy runs confirmed:
English/mixed runtime status surfaces, spontaneous implementation after a bug
report, incomplete Claude/Codex parity, unverified full `spec`/`plan`
checkpoint autonomy, and possible over-escalation in `analyze`. Next patch
should be designed from these observed failures, not as a direct `sage status`
string fix. No historical `.sage` migration was performed. Rollback is ordinary
git rollback of commit `cf28dea`.

Additional documentation test evidence lives in
`dummy-project-artifact-docs-report.md`: generated artifact body prose is mostly
Polish, but template headings, `handoff` labels, and some frontmatter titles
still leak English and need a follow-up patch.
