---
title: Brief — Codex enforcement activation and skill visibility semantics
status: closed-superseded
phase: brief
workflow: design
scope: standard
created: 2026-04-28
updated: 2026-04-28
owner: alexostl
handoff: |
  Key decisions: This is a design/architecture brief, not permission to
  implement immediately. The next agent must proceed through Sage gates:
  memory search, spec, [A]/[R], plan, [A]/[R], then implementation.
  Research context: `.sage/docs/analysis-alex-os-dev-enforcement-activation.md`,
  `.sage/docs/analysis-codex-enforcement-surface-audit.md`, current
  `bin/sage`, `runtime/platforms/codex/setup/generate-codex.sh`,
  `runtime/platforms/codex/HOOKS.md`, and `.sage/decisions.md`.
  Open questions: whether to activate hooks by default, provide an explicit
  project-level opt-in, or only improve diagnostics/docs; whether narrow
  palette should remain implemented by not deploying direct skills or move to
  a display-only mechanism if Codex exposes one.
  Next agent should: write a spec that separates desired guarantees from
  implementation levers, then propose the smallest change set that makes
  `sage update` / `sage init` behavior match the documented mental model.
---

# Brief — Codex enforcement activation and skill visibility semantics

## Problem

Recent work on the Codex port aimed to raise observable Sage methodology
compliance toward roughly 85-90%. The latest conversation showed a mismatch:
agents behave better than before, but the hard enforcement layer is not fully
active in consumer repos such as `alex-os-dev`.

The core confusion is that three states were treated as equivalent, but are not:

1. **Framework files are current on disk.**
2. **Generated Codex surfaces are current.**
3. **Runtime enforcement is active in the Codex session and Git clone.**

`sage update` currently achieves the first two in many cases. It does not
necessarily achieve the third.

There is a second, separate mismatch around the narrow skill palette:
`deploy_direct_skills: false` was described as hiding direct skills from the
GUI only. In Codex, `.agents/skills/` is both the GUI-visible list and the
native skill availability surface, so not deploying direct skills is not purely
cosmetic.

## Evidence Observed

Read-only inspection of `alex-os-dev` showed:

- `alex-os-dev/sage` had the same hashes as `sage-selfhost` and
  `~/.sage/framework` for key framework/enforcement files.
- `alex-os-dev/.codex/config.toml` had `codex_hooks = true`.
- `alex-os-dev/.codex/hooks.json` contained only a custom `SessionStart`
  hook for `.sage/scripts/verify-wiring.sh`.
- `UserPromptSubmit`, `PreToolUse`, and `PostToolUse` were not wired.
- `git config --get core.hooksPath` returned a custom path under
  `.git/hooks`, so Sage's `.githooks/pre-commit` was not active.
- `.sage/config.yaml` contained `deploy_direct_skills: false`, so direct
  Sage skills were intentionally not deployed to `.agents/skills/`.

Self-observation in `sage-selfhost` showed similar hook state:

- `codex_hooks = true` exists.
- `.codex/hooks.json` currently wires only `SessionStart`.
- Full Codex hook starter pack exists under `runtime/platforms/codex/hooks/`,
  but is not active unless copied/wired into `.codex/`.
- Pre-commit L5 is active in `sage-selfhost` itself because
  `core.hooksPath = .githooks`, but it only fires on commits.

## Desired Outcome

Future agents and users should have an accurate, operational mental model:

- Running `sage update` should either activate the promised enforcement or
  clearly state which enforcement remains inactive and how to activate it.
- `AGENTS.md` and generated docs should not imply that hooks are active merely
  because `[features].codex_hooks = true` exists.
- If the product promise is "Codex compliance improves to 85-90%", then the
  required runtime levers must actually be installed/wired, not merely present
  in the framework copy.
- Skill palette narrowing must be described honestly: either it is a true
  display-only feature, or it is a reduction in native direct-skill
  availability/discoverability.

## Non-Goals

- Do not mutate `alex-os-dev` without explicit user approval. That repo is
  out of scope for direct writes from a `sage-selfhost` session.
- Do not assume Codex hooks are stable enough to enable blindly everywhere
  without a spec-level decision.
- Do not forward-merge self-host-only defaults into `codex-port` or upstream
  without an explicit branch policy review.
- Do not treat this brief as implementation authorization.

## Design Questions For The Next Agent

1. Should `sage init` and/or `sage update` copy the Codex hook starter pack into
   `.codex/` automatically when `[features].codex_hooks = true` is present?
2. Should there be a separate `.sage/config.yaml` key for hook activation, for
   example `deploy_codex_hooks: true`, instead of inferring from
   `codex_hooks = true`?
3. Should `sage update` call `ensure_hooks_wired()` for existing projects, or
   is that too risky when `core.hooksPath` already has a custom value?
4. Should custom `core.hooksPath` produce a stronger warning or a status output
   that says L5 is dormant?
5. Should `deploy_direct_skills: false` remain the mechanism for narrow Codex
   GUI, or should we look for a true display-only skill visibility mechanism?
6. Should workflow skills that reference direct skills be made self-contained
   enough that direct-skill non-deployment cannot reduce behavior quality?
7. Should `/alex-os:config-status` or a Sage-native `sage status` surface report
   hook activation explicitly: files present, config enabled, runtime wired,
   and git hook active?

## Candidate Solution Directions

### Option A — Honest diagnostics only

Keep hooks opt-in. Update generated instructions and status tooling so agents
and users can see when enforcement files are present but inactive.

Pros: lowest risk, no surprise hooks in user repos.

Cons: likely does not raise compliance enough; relies on agents remembering to
activate optional levers.

### Option B — Explicit opt-in activation

Add project config such as `deploy_codex_hooks: true` and maybe
`install_git_hooks: true`. `sage init` / `sage update` then wire hooks only
when explicitly requested.

Pros: clear contract, portable per-project decision, avoids surprise.

Cons: still requires projects to opt in; old projects remain partially
protected until configured.

### Option C — Self-host default activation

For this self-host branch, enable Codex hook starter pack and L5 wiring by
default where safe, while preserving upstream-friendly defaults elsewhere.

Pros: matches the user's desired operating model fastest.

Cons: branch-policy sensitive; must avoid leaking self-host defaults upstream.

### Option D — Revisit narrow palette mechanism

Separate "GUI visibility" from "native skill availability" if Codex provides a
display-only config. If not, document the tradeoff and make workflow skills
carry enough operational content to compensate.

Pros: fixes the overclaim around skill hiding.

Cons: may be blocked by Codex platform capabilities.

## Success Criteria

A successful follow-up cycle should produce:

- A spec that clearly defines what "enforcement active" means for Codex:
  `AGENTS.md`, `.agents/skills/`, `.codex/config.toml`, `.codex/hooks.json`,
  `.codex/hooks/*.sh`, `core.hooksPath`, and `verification.md` close-out.
- A decision on hook activation policy for `sage-selfhost` vs `codex-port` /
  upstream.
- A decision on narrow palette semantics: cosmetic, behavioral, or accepted
  hybrid.
- Implementation that can be verified by a fresh consumer fixture, not only by
  reading generated files.
- Pasted test output showing before/after behavior:
  hooks absent/dormant → status reports inactive; hooks configured → gate fires.
- No writes to `alex-os-dev` unless the user explicitly approves that repo as
  a target.

## Recommended Next Step

Route this as `/sage:architect` if the next agent will decide hook policy and
branch semantics, or `/sage:build` if the user already chooses a direction.

Recommended starting point: `/sage:architect` because the key issue is not a
single bug. It is a contract mismatch between update behavior, generated docs,
runtime hook activation, Git hook activation, and skill visibility semantics.
