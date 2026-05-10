---
cycle_id: "20260507-codex-upstream-pr-prep"
title: "Codex upstream PR preparation"
workflow: build
phase: completed
status: completed
created: 2026-05-07
updated: 2026-05-09 12:18
owner: alexostl
scope:
  - ".sage/work/20260507-codex-upstream-pr-prep/*"
  - ".sage/work/20260507-hook-hardblock-confirmation-capture/*"
  - ".sage/work/20260508-alex-native-operating-model/real-use-findings.md"
  - ".sage/decisions.md"
  - ".gitignore"
  - ".github/workflows/*"
  - ".githooks/pre-commit"
  - "README.md"
  - "bin/sage"
  - "bin/sage-close"
  - "bin/sage-install-hooks"
  - "runtime/platforms/codex/**"
---

# Cycle: Codex upstream PR preparation

## State

**Current phase:** completed — the active upstream-PR-prep scope was adding
GitHub Actions CI for Codex-port Bats suites on PRs and pushes targeting
`selfhost` / `codex-port`.
**Plan:** `.sage/work/20260507-codex-upstream-pr-prep/plan.md`.
**Implementation:** `.github/workflows/codex-port-ci.yml`.
**Verification:** YAML parse, Codex Bats suites, and `git diff --check` passed
on 2026-05-07.

**Close note:** This cycle should no longer appear as active work. The broader
runtime/process findings captured below are preserved as historical context and
belong to separate follow-up fix work, not to upstream PR preparation.

## Context summary

`codex-port` now contains the selective Codex rewrite update and passed the
local Codex Bats suites. Before opening an upstream PR, self-host needs cleanup
so the public-facing branch story is clear and reviewers can verify behavior.
The old git pre-commit / `sage-close` model is still present on
`selfhost`, but it depends on the removed `verification_check.py` module
and does not match the new Codex hook architecture. Treat that old model as a
candidate cleanup target, not as an active feature.

## Decisions so far

- Do not include private/self-host research docs in GitHub branch tips.
- Treat `.sage/work/` as the source of truth for open actionable work.
- Keep the current Codex port based on Codex hooks: `SessionStart`,
  `PreToolUse`, `PostToolUse`, and `Stop`.
- Defer any future git pre-commit ergonomics to a new design that does not
  depend on `sage-close` or `verification_check.py`.
- Do not create `plan.md` for this cycle until the work is explicitly resumed
  and reaches the Sage planning checkpoint.
- Add GitHub Actions CI for Codex Bats suites as the active implementation
  scope before upstream PR readiness.
- Allow capture-only update to the paused Alex-native findings document when
  Alex reports additional runtime-localization evidence; this does not approve
  a runtime fix or broaden implementation scope.
- Keep the real Codex harness as optional/manual follow-up because it requires
  Codex CLI and model access.
- On resume, first cleanup target is branch hygiene: stop tracking private
  `.sage` context on self-host and codex-port, then remove the legacy git
  pre-commit close-out model from self-host.
- Correction from Alex: `.githooks` removal is behavior-affecting cleanup and
  should be routed through `sage:fix` with proper diagnosis/scope, not treated
  as a generic branch hygiene edit.

## Historical follow-up findings

These items were captured while this cycle was open, but they are not part of
the completed upstream-PR-prep CI scope. They should be consumed by a future
runtime/process fix cycle rather than reactivating this build cycle.

- **HIGH PRIORITY / next patch blocker: force workflow reclassification when
  downstream refresh discovers framework code changes.** Observed failure on
  2026-05-08: while refreshing `alex-os-dev` to the latest local
  `sage-selfhost`, the agent found and patched a real
  `runtime/platforms/codex/setup/lib/agents-md.sh` Stage 3 idempotency bug
  directly. The patch itself anchored `SAGE-MANAGED-END` detection to the real
  marker comment and added a regression, but the agent treated it as part of
  the downstream refresh instead of stopping and routing the Sage SelfHost code
  edit through `sage:fix`. Required fix: generated Developer Instructions,
  AGENTS.md guidance, and/or hook recovery UX must make semantic repo ownership
  explicit. If the requested task is "refresh repo B" but the next edit changes
  Sage framework behavior in repo A (`runtime/`, `bin/`, `core/`, setup tests,
  generated hook logic), the agent must hard-stop or soft-confirm a workflow
  reclassification before code changes. This should be tested with a regression
  scenario where a downstream `sage update` exposes a framework generator bug.
- **HIGH PRIORITY / next patch blocker: fix Sage workflow-routing escape hatch.**
  Observed failure: during branch cleanup, the agent silently reactivated this
  paused `build/intake` cycle and used it to perform behavior-affecting legacy
  `.githooks` removal. The user had not been told that the thread was operating
  inside a paused build/intake cycle. Sage guardrails caught missing active
  cycle, out-of-scope `.gitignore`, and missing Moderate+ plan, but did not
  enforce that the workflow type matched the semantic change. Required fix:
  when a change deletes or deprecates public behavior such as CLI commands,
  hook wiring, README promises, or tests, Sage must route/escalate to
  `sage:fix` or require an explicit user-visible checkpoint before continuing.
- **HIGH PRIORITY / next patch blocker: prevent silent paused-cycle activation.**
  Agents must not turn `status: paused` into `status: in-progress` as a hidden
  workaround after a hook block. If the only available context is a paused
  cycle, the agent must state the detected cycle to the user, explain whether it
  matches the requested work, and either resume it with explicit approval or
  create/use the correct workflow cycle. This should be enforced in guidance and
  ideally in Codex hook/recovery UX.
- **HIGH PRIORITY / next patch blocker: scope expansion must trigger semantic
  reclassification.** Observed failure: after `.gitignore` was blocked as
  outside scope, adding it to the manifest allowed the edit path to continue.
  Required fix: expanding manifest scope to include repo control files,
  user-facing docs, CLI entrypoints, deleted files, or tests should force a
  visible checkpoint and re-evaluate workflow (`build` vs `fix` vs cleanup)
  before code changes proceed.
- **HIGH PRIORITY / next patch fix: remove or redesign the legacy git-hook
  close-out model via `sage:fix`.** Final branch cleanup intentionally left
  `.githooks/pre-commit`, `bin/sage-close`, `bin/sage-install-hooks`,
  `sage install-hooks`, and README hook references in `selfhost`.
  They still appear to describe the old git pre-commit / close-out model, which
  does not match the current Codex hook architecture and may depend on removed
  validation pieces. Do not remove this as generic cleanup. Route it through a
  dedicated `sage:fix` with diagnosis, blast-radius check, compatibility
  decision, tests, and explicit user checkpoint.
- Strengthen Codex/Sage generated guidance for artifact routing:
  actionable TODOs, PR prep, next steps, candidate work, and "fix later"
  checklists should go to `.sage/work/<cycle>/manifest.md`, not `.sage/docs/`.
- Strengthen Codex/Sage generated guidance for intake state:
  `manifest.md` is valid for paused/intake work, but `plan.md` should only be
  created after an explicit workflow resume and planning checkpoint.
- Evaluate whether guidance is enough for the TODO-routing issue; if not, add
  a soft Codex audit warning when new `.sage/docs/` files look like actionable
  work rather than durable knowledge.
- Update `sage status` so `intake/paused` cycles clearly show that
  "manifest only, no plan yet" is the correct state.
- Fix Codex hook bootstrap/recovery UX for workflow artifacts:
  saying "entering workflow" is not enough; the hook recognizes a workflow only
  after an in-progress `manifest.md` exists. Avoid the trap where a premature
  `mkdir .sage/work/<cycle>` prevents the bootstrap allowance from creating the
  first manifest, and make the recovery message/action explicit.
- Review Sage Wiki workflow findings captured in
  `.sage/work/20260507-sage-wiki-upstream-update/review-findings.md` before the
  next workflow-routing/bootstrap patch: define an operator-action escape hatch
  for direct runtime maintenance during an active workflow, and resolve the
  `/analyze` first-write/bootstrap UX mismatch where the hook correctly blocks
  without making the legal manifest path obvious.
- Add a soft-confirmation path for scope/active-cycle hard blocks, captured in
  `.sage/work/20260507-hook-hardblock-confirmation-capture/manifest.md`: when a
  requested write is outside the active cycle or the hook detects ambiguous
  active state, the hard block should become a strong warning that requires the
  agent to confirm with the user and then proceed through an explicit, audited
  route instead of forcing hook spelunking or path workarounds.
- Add Codex review-finding capture guidance and/or hook UX:
  when a thread review produces actionable process findings, route them into
  `.sage/work/<cycle>/manifest.md` as intake TODOs instead of attempting to
  append them directly to `.sage/decisions.md` without an active cycle.
  Technical context to preserve for the future fix:
  `core/workflows/review.workflow.md` Step 5 currently instructs agents to
  prepend review findings to `.sage/decisions.md`, while Codex
  `pre-tool-validate.sh` only permits mutations when
  `active_init.sh` finds a manifest with `status: in-progress`. Manifests in
  `status: paused` or `status: completed` are not active for the hook. The fix
  should resolve that contract explicitly, preferably by having review create
  or resume a lightweight manifest before durable writes, rather than by adding
  a broad exception for `.sage/decisions.md`.
- Add the reviewed thread compliance cases as Codex/Sage regression examples:
  `019dff35` and `019dff5b` show correct review-driven recovery, `019dff66`
  shows lightweight read-only investigation that should not force artifacts,
  and `019dfff8` is the failure case where a multi-file fix skipped root-cause
  approval, scope approval, and Moderate fix artifacts before code edits.
- Strengthen Codex guidance for cross-repo fix scope:
  if a task starts in `sage-selfhost` but the actual edits land in another
  Sage-managed repo such as `alex-os-dev`, the target repo's `.sage` state and
  fix scope gates still apply. Do not treat cross-repo edits as exempt from
  `manifest.md` / `plan.md` requirements.
- Fix Codex AGENTS.md Stage 3 idempotency:
  `runtime/platforms/codex/setup/lib/agents-md.sh` currently matches
  `SAGE-MANAGED-END` too loosely when preserving user territory. The generated
  header text mentions ``<!-- SAGE-MANAGED-END -->`` before the actual marker,
  so the second Stage 3 run preserves almost the entire prior generated block
  and duplicates generated `## Constitution` sections below the real marker.
  Current bad result after running Stage 3 twice on a fresh temp target:
  `rg -c '^## Constitution$' "$tmp/AGENTS.md"` returns `2`;
  `rg -c '^<!-- SAGE-MANAGED-END' "$tmp/AGENTS.md"` returns `2`;
  `rg -c 'SAGE-MANAGED-END' "$tmp/AGENTS.md"` returns `3`.
  Expected result: exactly one `## Constitution`, exactly one actual marker
  comment line, and no duplicated generated block below the marker. The
  explanatory header mention may remain, but must not be treated as the marker.
  The fix should anchor marker detection/preservation to the actual marker
  comment line, for example `^<!-- SAGE-MANAGED-END`, in both `grep` and
  `awk`/`sed` preservation logic.
  Repro:
  `SAGE_FRAMEWORK=/Users/alexostl/Developer/sage-selfhost runtime/platforms/codex/setup/generate-codex.sh --target "$tmp" --preset base --stage 3`
  twice, then inspect the three `rg -c` counts above.
  Suggested regression tests in
  `runtime/platforms/codex/setup/tests/stage3-agents-md.bats`:
  running Stage 3 twice on a fresh target remains idempotent with one
  `## Constitution`, one actual marker comment line, and no duplicated
  generated block below marker; user content appended below the real marker is
  still preserved on re-run; the explanatory header line containing backticked
  ``<!-- SAGE-MANAGED-END -->`` does not count as the marker.
- Fix Codex config Stage 4 duplicate `[features]` self-bricking:
  `runtime/platforms/codex/setup/lib/config-toml.sh` always generates
  `[features] codex_hooks = true` and `[history]` inside the managed block, but
  `_write_with_block_strategy` preserves existing postlude content verbatim
  when markers are present. If a project has the old user-owned fallback
  `[features] codex_hooks = true` below the managed block, a later
  `sage update` leaves duplicate `[features]` tables. Codex CLI then fails to
  load the project config with `TOML parse error ... duplicate key`.
  Observed repro:
  run Stage 4 once, append a postlude containing only
  `[features]` / `codex_hooks = true`, then run Stage 4 again. The resulting
  config has two `^[features]` headers. `yq -p toml` on this machine returned
  success, so it is not sufficient as the only guard; Python `tomllib` and
  `codex exec --skip-git-repo-check` both reject the duplicate table.
  Expected fix:
  after composing `.codex/config.toml`, remove only the legacy fallback
  user-owned `[features]` section when it contains no preserved data beyond
  `codex_hooks = true` plus whitespace/comments. If user-owned `[features]`
  contains other keys, do not silently delete it; either preserve/migrate those
  keys according to an explicit design or stop with a clear error and backup.
  Do not alter unrelated user-owned sections.
  Add a final validation guard that does not rely solely on `yq -p toml`:
  detect duplicate critical singleton tables such as `[features]` and
  `[history]` after composition and fail with a readable message if they remain.
  Suggested regression test in
  `runtime/platforms/codex/setup/tests/stage4-config-toml.bats`:
  prepare config with managed block plus postlude `[features] codex_hooks =
  true`, rerun Stage 4, assert exactly one `[features]` table remains, and
  assert the final config parses with a strict TOML parser or the best
  available project-local equivalent.
- Add CI for the Codex port Bats suites:
  `bats runtime/platforms/codex/hooks/tests runtime/platforms/codex/setup/tests`.
  This was the active scope for this cycle and is now completed.
- Run one real Codex smoke/harness pass before marking the upstream PR ready:
  `runtime/platforms/codex/harness/run-harness.sh`.

## Open questions

- Whether to open the upstream PR as draft first or wait until CI + harness are
  both green. Current recommendation: draft after CI exists, ready after harness.

## Verification

- 2026-05-07: `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/codex-port-ci.yml"); puts "workflow yaml ok"'`
  passed with `workflow yaml ok`.
- 2026-05-07: `bats runtime/platforms/codex/hooks/tests runtime/platforms/codex/setup/tests`
  passed `272/272`.
- 2026-05-07: `git diff --check` passed.

## Handoff guidance

Do not put this checklist back into `.sage/docs/`; this is actionable work, not
project knowledge. Do not implement directly from this manifest. Resume the
cycle, classify scope, and create the required Sage artifact before code edits.
