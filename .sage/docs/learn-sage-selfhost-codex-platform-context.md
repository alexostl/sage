# Learn: `sage-selfhost` Codex Platform Context

## Purpose

This note captures the subset of Codex/self-hosting context that future working
sessions need inside `.sage`. It is not the full Codex adapter manual. It is
the operational bridge that tells a session what matters before diving into the
deeper adapter docs.

## What Codex Support Means In This Repository

In `sage-selfhost`, Codex support means Sage has a release-ready adapter that maps
Sage workflows onto Codex-native surfaces without pretending Codex is Claude
Code.

Current core posture:

- `AGENTS.md` is the always-on repository instruction entrypoint
- `.agents/skills/` is the primary Sage skill surface
- `.codex/config.toml` is the native project config surface
- `.sage/` stays the shared project state layer
- worktrees, Git flows, automations, and `/review` are treated as native Codex
  features, not reimplemented by Sage

## Generated Codex Surfaces And Their Roles

| Surface | Role |
| --- | --- |
| `AGENTS.md` | Always-on Codex instructions for Sage routing, state-first behavior, and workflow rules |
| `.agents/skills/` | Workflow and direct skills used by Codex discovery |
| `.codex/config.toml` | Project-scoped Codex config, including Sage-managed config blocks and MCP |
| `.sage/` | Shared project state across Codex, Claude Code, and other platforms |

## Current Adapter Posture

### Workflow entry

Preferred entrypoints are:

- `$sage`
- `$build`
- `$fix`
- `$architect`
- `$continue`
- `$status`
- `$review`

Codex native `/review` remains the best diff-review companion.

### Skill surface

`.agents/skills/` remains the primary contract. `.codex/skills/` may exist as a
native Codex concept, but Sage does not treat it as the main surface yet.

### Config posture

Sage manages a marked block inside `.codex/config.toml`. User-owned Codex
settings outside that block should be preserved across regeneration.

### Worktrees and Git flows

Codex-native worktrees and built-in Git flows are assumed to exist when the repo
is under Git. Sage relies on those surfaces rather than creating parallel Git or
worktree infrastructure.

### Automations

Codex automations are native platform features. Sage documents patterns and
templates for them, but does not run its own automation scheduler inside the
adapter.

### Hooks

Hooks are real but experimental and opt-in. The current posture is conservative:

- no claim of Claude-style lifecycle parity
- starter materials exist
- nothing is enabled by default

The practical implication for repo work is: rely on Sage workflow discipline
first, and treat hooks as optional extra guardrails.

## Self-Hosted Repository Caveat

This repository uses a private self-hosting capability so Sage can operate on
the Sage framework repository itself.

Practical consequences:

- the framework checkout is reused in place
- `.sage/`, `AGENTS.md`, `.agents/skills/`, and `.codex/config.toml` are
  generated into this repo
- there is no nested framework copy required for self-host mode
- self-host behavior is a branch-local maintainer capability, not a default
  public-product assumption

For routine work, the important takeaway is that this repo is both the framework
source and an active Sage project. Keep that dual role explicit when writing
plans, docs, or operating guidance.

## Canonical Deeper Docs

Use these when you need detail beyond this summary:

- `runtime/platforms/codex/README.md`
- `runtime/platforms/codex/INSTALL.md`
- `runtime/platforms/codex/HOOKS.md`
- `runtime/platforms/codex/AUTOMATIONS.md`
- `runtime/platforms/README.md`

Historical context during parity checks only:

- `to-rewrite-in-sage/SELF_HOSTING.md`
- `to-rewrite-in-sage/runtime/platforms/codex/IMPLEMENTATION_READY_HANDOFF.md`

## Working Rule

If a future task touches Codex adapter behavior, start with this note and then
jump to the deeper runtime docs above. Do not begin from the legacy rewrite
folder unless you are explicitly validating parity or checking historical handoff
context.
