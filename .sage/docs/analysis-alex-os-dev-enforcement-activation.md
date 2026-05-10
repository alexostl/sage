---
title: "Analysis: alex-os-dev enforcement activation after Sage update"
status: completed
created: 2026-04-28
scope: analysis
related:
  - /Users/alexostl/Developer/alex-os-dev
  - runtime/platforms/codex/setup/generate-codex.sh
  - runtime/platforms/codex/HOOKS.md
  - bin/sage
---

# Analysis: alex-os-dev enforcement activation after Sage update

## Question

Why did `alex-os-dev` not behave as if all recent Sage Codex enforcement
changes were active, even though the project had been regenerated with the
latest framework?

## Finding 1 — Framework files are current

`/Users/alexostl/Developer/alex-os-dev/sage` has the same file hashes as both:

- `/Users/alexostl/Developer/sage-selfhost`
- `/Users/alexostl/.sage/framework`

Checked files included:

- `bin/sage`
- `bin/sage-close`
- `bin/sage-install-hooks`
- `.githooks/pre-commit`
- `runtime/platforms/codex/hooks/pre-prompt.sh`
- `runtime/platforms/codex/hooks/lib/verification_check.py`
- `runtime/platforms/codex/setup/generate-codex.sh`

Conclusion: the framework content did reach `alex-os-dev`.

## Finding 2 — Codex hook enforcement is not activated by `sage update`

The current Codex generator creates/regenerates:

- `AGENTS.md`
- `.agents/skills/`
- `.codex/config.toml`

It does not copy `sage/runtime/platforms/codex/hooks.example.json` to
`.codex/hooks.json`, and it does not copy `sage/runtime/platforms/codex/hooks/*.sh`
into `.codex/hooks/`.

The docs explicitly frame Codex hooks as experimental and opt-in:

- enable `[features].codex_hooks = true`
- then copy starter hook files into `.codex/`
- restart/start a new Codex session

In `alex-os-dev`, `.codex/config.toml` has `codex_hooks = true`, but
`.codex/hooks.json` contains only a custom `SessionStart` hook for
`.sage/scripts/verify-wiring.sh`. It does not include:

- `UserPromptSubmit`
- `PreToolUse`
- `PostToolUse`

Conclusion: the hook scripts exist in the framework copy, but the Codex
runtime was not wired to run them.

## Finding 3 — Pre-commit L5 is present but dormant

`bin/sage` includes `ensure_hooks_wired()`, and `sage init` / `sage new`
call it. The helper copies `.githooks/pre-commit` into the project and sets
`core.hooksPath = .githooks` only when the existing `core.hooksPath` is empty
or already `.githooks`.

In `alex-os-dev`, `git config --get core.hooksPath` returns:

`/Users/alexostl/Developer/alex-os-dev/.git/hooks`

Because this is a custom value, Sage intentionally leaves it unchanged.
The project has `sage/.githooks/pre-commit`, but not an active root
`.githooks/pre-commit`.

Conclusion: L5 is available in the copied framework but is not active for
commits in `alex-os-dev`.

## Finding 4 — Narrow GUI palette is not purely cosmetic

`deploy_direct_skills: false` in `.sage/config.yaml` makes the Codex generator
skip copying direct Sage skills into `.agents/skills/`.

Workflow skills remain deployed, so `/sage:build`, `/sage:fix`, `/sage:analyze`,
etc. are available. Source direct skills still exist inside the copied
framework under `sage/skills/`.

However, for Codex the GUI-visible skill list and the native skill availability
surface are both `.agents/skills/`. Therefore hiding direct skills from the GUI
also means they are not natively exposed as direct Codex skills. They may still
be read explicitly from disk by workflow skills or by an agent that knows the
path, but they are less discoverable and less automatically selectable.

Conclusion: the previous claim that this is "only hiding in the interface" was
too strong. It is mostly safe for workflow-driven Sage use, but it does change
native direct-skill availability/discoverability in Codex.

## Summary

The observed behavior in the pasted conversation is consistent with this state:

- current framework files copied: yes
- current AGENTS.md instructions regenerated: yes
- workflow skill palette deployed: yes
- Codex UserPromptSubmit / PreToolUse / PostToolUse hooks active: no
- Git pre-commit L5 active: no
- direct skills deployed as native Codex skills: no

Short version: `alex-os-dev` had the latest framework model on disk, but not the
full execution model activated.
